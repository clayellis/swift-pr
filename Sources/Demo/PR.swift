import SwiftPR

@main
struct Demo: PRCheck {
    func run() async throws {
        guard let prBody = pr.pullRequest.body, !prBody.isEmpty else {
            pr.output.info("Here is some info.")
            pr.output.warning("Not required, but you should fix this.")
            pr.output.error("You made a mistake that needs to be fixed.")
            return
        }
    }
}
