import SwiftPR

@main
struct Demo: PRCheck {
    static func runChecks() async throws {
        guard let prBody = pr.pullRequest.body, !prBody.isEmpty else {
            pr.warning("Please add a description to your pull request.")
            return
        }
    }
}
