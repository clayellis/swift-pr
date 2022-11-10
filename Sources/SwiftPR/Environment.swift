public struct Environment {
    var environment: [String: String] = [:]

    var dump: String {
        environment.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
    }

    public subscript(key: String) -> String? {
        environment[key]
    }

    subscript(variable: Variable) -> String? {
        self[variable.rawValue]
    }

    func require(_ variable: Variable) throws -> String {
        guard let value = self[variable] else {
            throw RequiredVariableError(variable: variable)
        }

        return value
    }
}

extension Environment {
    struct RequiredVariableError: Error {
        let variable: Variable
    }

    enum Variable: String {
        case repository = "GITHUB_REPOSITORY"
        case repositoryOwner = "GITHUB_REPOSITORY_OWNER"
        case refName = "GITHUB_REF_NAME"
        case workspace = "GITHUB_WORKSPACE"
        case ci = "CI"
        case eventName = "GITHUB_EVENT_NAME"
        case token = "GITHUB_TOKEN"
    }
}

extension Environment {
    /// Example: `"LumioHX/hx-ios"`
    var repository: String? {
        self[.repository]
    }

    /// Example: `"LumioHX"`
    var repositoryOwner: String? {
        self[.repositoryOwner]
    }

    /// Example: `"59/merge"`
    var refName: String? {
        self[.refName]
    }

    /// The root of the cloned repository.
    /// Example: `"/Users/clay/actions-runner/_work/hx-ios/hx-ios"`
    var workspace: String? {
        self[.workspace]
    }

    /// Example: `"true"`
    var ci: String? {
        self[.ci]
    }

    /// Example: `"pull_request"`
    var eventName: String? {
        self[.eventName]
    }

    /// Example: `"abc123"`
    var token: String? {
        self[.token]
    }
}

extension Environment {
    var isCI: Bool {
        ci == "true"
    }

    var isPullRequest: Bool {
        eventName == "pull_request"
    }
}
