struct Message: Codable {
    enum Severity: String, CaseIterable, Codable {
        case error
        case warning
        case info
        case success

        var symbol: String {
            switch self {
            case .error: return "🚫"
            case .warning: return "⚠️"
            case .info: return "ℹ️"
            case .success: return "✅"
            }
        }
    }

    let message: String
    let severity: Severity
}

extension PR {
    public func error(_ message: String) {
        output.messages.append(Message(message: message, severity: .error))
    }

    public func warning(_ message: String) {
        output.messages.append(Message(message: message, severity: .warning))
    }

    public func info(_ message: String) {
        output.messages.append(Message(message: message, severity: .info))
    }
}
