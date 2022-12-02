import Arguments
import Foundation
import OctoKit
import SwiftEnvironment

public protocol PRCheck {
    static var name: String { get }
    init()
    func run() async throws
}

public extension PRCheck {
    static var name: String {
        "\(self)"
    }
}

// TODO: Add tests
// TODO: Add support for adding a comment to specific file/line?
// TODO: Next up is to make this thing work in GitHub Actions
// - make a repo for swift-pr
// - audit public interface
// - add documentation to public interfaces

public enum PRCheckError: Error {
    case missingInfoForSwiftPRComment
    case notRunningInPullRequest
    case invalidConversion(String)
}

extension PRCheck {
    // TODO: Include a version string in the comment prefix so we can introduce new features without breaking old prs?
    // <!--__swift-pr@1.0.0__-->

    public static var id: String { "\(self)" }
    public static var commentID: String { "<!--__swift-pr_\(id)__-->" }

    /// Accessing this value outside of ``run()`` is unsupported.
    public static var pr: PR { .shared }

    /// Accessing this value outside of ``run()`` is unsupported.
    public var pr: PR { .shared }

    public static var statusContext: String {
        "SwiftPR / \(name)"
    }

    public static var statusState: Status.State {
        if !pr.output.messages(severity: .error).isEmpty {
            return .failure
        }

        return .success
    }

    public static func getSwiftPRComment(_ check: PRCheck.Type = Self.self, owner: String? = nil, repository: String? = nil, prNumber: Int? = nil) async throws -> Comment? {
        var owner = owner
        var repository = repository
        var prNumber = prNumber

        if owner == nil || repository == nil {
            (owner, repository) = try ProcessEnvironment.GitHub.requireOwnerRepository()
        }

        if prNumber == nil {
            prNumber = try ProcessEnvironment.GitHub.requirePullRequestNumber()
        }

        guard let owner, let repository, let prNumber else {
            // This should never happen
            throw PRCheckError.missingInfoForSwiftPRComment
        }

        let pullRequestComments = try await pr.github.issueComments(owner: owner, repository: repository, number: prNumber)
        let prCheckComment = pullRequestComments.first(where: { $0.body.hasPrefix(check.commentID) })
        return prCheckComment
    }

    public static func main() async throws {
        var _owner: String?
        var _repository: String?
        var _runID: String?
        var _log: ((String) -> Void)?
        var _verboseLog: ((String) -> Void)?
        var _setStatus: ((_ state: Status.State, _ description: String) async throws -> Void)?
        var _createOrUpdateSwiftPRComment: (() async throws -> Void)?

        do {
            pr.output.checkName = name
            pr.environment = ProcessEnvironment.self
            let githubEnvironment = ProcessEnvironment.github

            var arguments = Arguments(usage: Usage(
                overview: "Run swift-pr locally, either on the command line or in Xcode. If running in Xcode, pass the required arguments by editing your executable's scheme, then adding them under the Run > Arguments tab's \"Arguments Passed On Launch\" section. You can also simulate running in GitHub actions by passing the appropriate variables under the \"Environment Variables\" section.",
                commands: [
                    "your-check-name",
                    .option("pr", required: true, description: "Pull request url."),
                    .option("token", required: true, description: "GitHub token. The token can be added to the environment by adding 'env: (newline) GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}' to the action that triggers this swift-pr check. The default token is one that the GitHub Actions bot can use to comment on your pull request."),
                    .option("root", required: false, description: "The location of the repository's root directory."),
                    .flag("dry-run", description: "Disables posting the swift-pr comment to the pull request."),
                    .flag("verbose", description: "Enables verbose logs."),
                ]
            ))

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

            if githubEnvironment.isCI {
                guard githubEnvironment.isPullRequest else {
                    throw PRCheckError.notRunningInPullRequest
                }

                (owner, repository) = try githubEnvironment.requireOwnerRepository()
                number = try githubEnvironment.requirePullRequestNumber()
                token = try githubEnvironment.$token.require()
                root = try githubEnvironment.$workspace.require()
                _runID = githubEnvironment.runID

            } else {
                // TODO: Print "usage" if any of these fail
                let prOption: PullRequestOption = try arguments.consumeOption(named: "--pr")
                (owner, repository, number) = (prOption.owner, prOption.repository, prOption.number)
                token = try arguments.consumeOption(named: "--token")
                root = try? arguments.consumeOption(named: "--root")
            }

            _owner = owner
            _repository = repository

            verboseLog("""
                Details:
                - Owner: \(owner)
                - Repository: \(repository)
                - Number: \(number)
                - Token: \(token) (length: \(token.count))
                - Root: \(root ?? "nil")
                - Run ID: \(_runID ?? "nil")
                - Dry Run: \(dryRun)
                """
            )

            // TODO: This is necessary for private SAML SSO repos. But does it break public repos? I kind of doubt it. Worth testing though.
            let github = Octokit(TokenConfiguration(bearerToken: token))
            pr.github = github

            verboseLog("Getting pull request...")
            let pullRequest = try await github.pullRequest(owner: owner, repository: repository, number: number)
            pr.pullRequest = pullRequest

            // TODO: If swift-pr is run during ci/cd and the head has changed, the sha will have changed. We need to get the new head.
            let sha = pullRequest.head!.sha!

            verboseLog("Getting pull request comments...")
            var prCheckComment = try await getSwiftPRComment(owner: owner, repository: repository, prNumber: number)
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
                    context: statusContext + (githubEnvironment.isCI ? "" : " (local)")
                )
            }

            _setStatus = setStatus(state:description:)

            func createOrUpdateSwiftPRComment() async throws {
                let commentBody = """
                    \(commentID)

                    \(try pr.output.body())

                    <p align="right">
                      Generated by :traffic_light: <a href="https://github.com/clayellis/swift-pr">swift-pr</a> against \(sha)
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
            let check = Self.init()
            try await check.run()
            verboseLog("Checks complete")

            let state = statusState

            if state == .success {
                pr.output.messages.append(Message(message: "All checks passed", severity: .success))
            }

            try await createOrUpdateSwiftPRComment()

            var description: String
            if state == .success {
                description = "All checks passed"
                let warningCount = pr.output.messages(severity: .warning).count
                if warningCount > 0 {
                    description += " (\(warningCount) \(warningCount == 1 ? "warning" : "warnings"))"
                }
            } else {
                let errorCount = pr.output.messages(severity: .error).count
                description = "Failed with \(errorCount) \(errorCount == 1 ? "error" : "errors")"
            }

            try await setStatus(state: state, description: description)

            verboseLog("Done!")
        } catch {
            _log?("""
                Caught error:
                \(error.localizedDescription)
                \(error)
                Exiting
                """
            )

            pr.output.error("`swift-pr` caught an error. See logs below.")
            pr.output.markdown("""
                ## Logs
                ```
                \(error.localizedDescription)
                \(error)
                ```
                """
            )

            if let _owner, let _repository, let _runID {
                // TODO: Use the jobs API (https://docs.github.com/en/rest/actions/workflow-jobs#list-jobs-for-a-workflow-run) to get the job id for the run
                // (Use filter: latest)
                // Then the url could be https://github.com/\(_owner)/\(_repository)/actions/runs/\(_runID)/jobs/\(_jobID)
                // There isn't a consistent way that I can see though to determine which job was the one that ran swift-pr
                // We could guess that it's the last one with the status "completed" and conclusion "failure"? But there may be later jobs that still ran and failed.
                pr.output.markdown("See [full logs](https://github.com/\(_owner)/\(_repository)/actions/runs/\(_runID))")
            }

            updatePR: do {
                _verboseLog?("Updating PR...")

                guard let _createOrUpdateSwiftPRComment, let _setStatus else {
                    _verboseLog?("Failed to update PR because _createOrUpdateSwiftPRComment and _setStatus were nil.")
                    break updatePR
                }

                try await _createOrUpdateSwiftPRComment()
                try await _setStatus(.error, "An error occurred. See details for more info.")
            } catch {
                _verboseLog?(
                    """
                    An error occurred while updating PR:
                    \(error.localizedDescription)
                    \(error)
                    """
                )
            }

            throw error
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
