import Foundation
import OctoKit

public protocol PRCheck {
    static func runChecks() async throws
}

// TODO: Add tests
// TODO: Add support for adding a comment to specific file/line?
// TODO: Next up is to make this thing work in GitHub Actions
// - make a repo for swift-pr
// - audit public interface
// - add documentation to public interfaces

enum PRCheckError: Error {
    case notRunningInPullRequest
    case invalidConversion(String)
}

extension PRCheck {
    static var commentPrefix: String { "<!--__swift-pr__-->" }

    /// Accessing this value outside of ``runChecks()`` is unsupported.
    public static var pr: PR { .shared }

    public static func main() async {
        var _log: ((String) -> Void)?
        var _verboseLog: ((String) -> Void)?
        var _setStatus: ((_ state: Status.State, _ description: String) async throws -> Void)?
        var _createOrUpdateSwiftPRComment: (() async throws -> Void)?

        do {
            let environment = Environment(environment: ProcessInfo.processInfo.environment)
            pr.environment = environment

            var arguments = ArgumentParser()

            let dryRun = arguments.consumeFlag(named: "--dry-run")
            let verbose = arguments.consumeFlag(named: "--verbose")

            func log(_ message: String) {
                print(message)
            }

            func verboseLog(_ message: String) {
                guard verbose else { return }
                log(message)
            }

            _log = log
            _verboseLog = verboseLog

            pr.log = log
            pr.verboseLog = verboseLog

            var owner: String
            var repository: String
            var number: Int
            var token: String
            var root: String?

            if environment.isCI {
                guard environment.isPullRequest else {
                    throw PRCheckError.notRunningInPullRequest
                }

                owner = try environment.require(.repositoryOwner)
                let fullRepository = try environment.require(.repository)
                repository = fullRepository.removingPrefix("\(owner)/")
                let fullRefName = try environment.require(.refName)
                let refNumberString = fullRefName.removingSuffix("/merge")
                guard let refNumber = Int(refNumberString) else {
                    throw PRCheckError.invalidConversion("Failed to convert refNumberString '\(refNumberString)' to Int")
                }
                number = refNumber
                token = try environment.require(.token)
                root = environment[.workspace]

            } else {
                // TODO: Print "usage" if any of these fail
                let prOption: PullRequestOption = try arguments.consumeOption(named: "--pr")
                (owner, repository, number) = (prOption.owner, prOption.repository, prOption.number)
                token = try arguments.consumeOption(named: "--token")
                root = try? arguments.consumeOption(named: "--root")
            }

            verboseLog("""
                Details:
                - Owner: \(owner)
                - Repository: \(repository)
                - Number: \(number)
                - Token: \(token) (length: \(token.count))
                - Root: \(root ?? "nil")
                - Dry Run: \(dryRun)
                - Environment:
                \(environment.dump.bulleted().indented())
                """
            )

            // TODO: This is necessary for private SAML SSO repos. But does it break public repos? I kind of doubt it. Worth testing though.
            let github = Octokit(TokenConfiguration(bearerToken: token))
            pr.github = github

            verboseLog("Getting pull request...")
            let pullRequest = try await github.pullRequest(owner: owner, repository: repository, number: number)
            pr.pullRequest = pullRequest

            let sha = pullRequest.head!.sha!
            verboseLog("Getting pull request comments...")
            let pullRequestComments = try await github.issueComments(owner: owner, repository: repository, number: number)
            var prCheckComment = pullRequestComments.first(where: { $0.body.hasPrefix(commentPrefix) })
            pr.prCheckComment = prCheckComment

            func setStatus(state: Status.State, description: String) async throws {
                guard !dryRun else { return }

                verboseLog("Setting commit status to \(state)...")
                _ = try await github.createCommitStatus(
                    owner: owner,
                    repository: repository,
                    sha: sha,
                    state: state,
                    targetURL: prCheckComment?.htmlURL.absoluteString,
                    description: description,
                    context: "swift-pr (\(environment.isCI ? "pull_request" : "local"))"
                )
            }

            _setStatus = setStatus(state:description:)

            func createOrUpdateSwiftPRComment() async throws {
                let commentBody = """
                \(commentPrefix)

                \(pr.messagesMarkdown)

                \(pr.markdown.joined(separator: "\n\n"))

                <p align="right">
                  Generated by :traffic_light: <a href="https://github.com/lumiohx/swift-pr">swift-pr</a> against \(sha)
                </p>
                """

                if dryRun || verbose {
                    verboseLog("Generating message:")
                    log(commentBody)
                }

                if !dryRun {
                    if let existingComment = prCheckComment {
                        verboseLog("Updating swift-pr comment...")
                        prCheckComment = try await github.patchIssueComment(owner: owner, repository: repository, number: existingComment.id, body: commentBody)
                    } else {
                        verboseLog("Creating swift-pr comment...")
                        prCheckComment = try await github.commentIssue(owner: owner, repository: repository, number: number, body: commentBody)
                    }
                }
            }

            _createOrUpdateSwiftPRComment = createOrUpdateSwiftPRComment

            verboseLog("Getting pull request diff...")
            let diff = try await Diff(owner: owner, repository: repository, number: number, token: token)
            pr.diff = diff

            let files = FileManager.default
            if let root {
                verboseLog("Setting current directory path to \(root) ...")
                files.changeCurrentDirectoryPath(root)
            }
            pr.files = files

            try await setStatus(state: .pending, description: "Running PR checks...")

            verboseLog("Running checks...")
            try await runChecks()
            verboseLog("Checks complete")

            let state = pr.statusState

            if state == .success {
                pr.messages.append(Message(message: "All checks passed", severity: .success))
            }

            try await createOrUpdateSwiftPRComment()

            var description: String
            if state == .success {
                description = "All checks passed"
                let warningCount = pr.messages(severity: .warning).count
                if warningCount > 0 {
                    description += " (\(warningCount) \(warningCount == 1 ? "warning" : "warnings"))"
                }
            } else {
                let errorCount = pr.messages(severity: .error).count
                description = "Failed with \(errorCount) \(errorCount == 1 ? "error" : "errors")"
            }

            try await setStatus(state: state, description: description)

            verboseLog("Done!")
            exit(0)
        } catch {
            _log?("""
                Caught error:
                \(error)
                \(error.localizedDescription)
                Exiting
                """
            )

            pr.error("`swift-pr` caught an error.")
            pr.markdown("""
                ## Logs
                ```
                \(error)
                \(error.localizedDescription)
                ```
                """
            )

            updatePR: do {
                _verboseLog?("Updating PR...")

                guard let _createOrUpdateSwiftPRComment, let _setStatus else {
                    _verboseLog?("Failed to update PR because _createOrUpdateSwiftPRComment and _setStatus were nil.")
                    break updatePR
                }

                try await _createOrUpdateSwiftPRComment()
                try await _setStatus(.error, "An error occurred. Check logs for more info.")
            } catch {
                _verboseLog?(
                    """
                    An error occurred while updating PR:
                    \(error)
                    \(error.localizedDescription)
                    """
                )
            }
            exit(1)
        }
    }
}

extension String {
    func removingPrefix(_ prefix: String) -> String {
        if hasPrefix(prefix) {
            return String(self.dropFirst(prefix.count))
        } else {
            return self
        }
    }

    func removingSuffix(_ suffix: String) -> String {
        if hasSuffix(suffix) {
            return String(self.dropLast(suffix.count))
        } else {
            return self
        }
    }

    func indented(tabs: Int = 1) -> String {
        components(separatedBy: "\n")
            .map { Array(repeating: "\t", count: tabs).joined() + $0 }
            .joined(separator: "\n")
    }

    func bulleted(bullet: String = "- ") -> String {
        components(separatedBy: "\n")
            .map { bullet + $0 }
            .joined(separator: "\n")
    }
}
