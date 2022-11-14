import SwiftEnvironment

extension ProcessEnvironment.GitHub {
    @EnvironmentVariable("GITHUB_TOKEN")
    static var token
}
