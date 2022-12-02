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

extension PR.Output {
    public mutating func error(_ message: String) {
        messages.append(Message(message: message, severity: .error))
    }

    public mutating func warning(_ message: String) {
        messages.append(Message(message: message, severity: .warning))
    }

    public mutating func info(_ message: String) {
        messages.append(Message(message: message, severity: .info))
    }
}
