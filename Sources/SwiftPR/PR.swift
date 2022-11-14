import Foundation
import OctoKit
import SwiftEnvironment

public class PR {
    internal static let shared = PR()

    internal var messages = [Message]()
    internal var markdown = [String]()

    public internal(set) var log: (_ message: String) -> Void = { _ in }
    public internal(set) var verboseLog: (_ message: String) -> Void = { _ in }

    public internal(set) var diff = Diff()
    public internal(set) var files = FileManager.default
    public internal(set) var github = Octokit()
    public internal(set) var prCheckComment: Comment?
    public internal(set) var pullRequest: PullRequest!
    public internal(set) var environment = ProcessEnvironment.self
}

extension PR {
    public func markdown(_ markdown: String) {
        self.markdown.append(markdown)
    }
}

extension PR {
    internal var statusState: Status.State {
        if !messages(severity: .error).isEmpty {
            return .failure
        }

        return .success
    }
}
