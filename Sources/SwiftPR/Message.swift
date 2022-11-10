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
        messages.append(Message(message: message, severity: .error))
    }

    public func warning(_ message: String) {
        messages.append(Message(message: message, severity: .warning))
    }

    public func info(_ message: String) {
        messages.append(Message(message: message, severity: .info))
    }
}

extension PR {
    func messages(severity: Message.Severity) -> [Message] {
        messages.filter { $0.severity == severity }
    }
}

extension PR {
    var messagesMarkdown: String {
        var table = MarkdownTable()
        table.setColumns(["": .center, "Message": .left])
        for severity in Message.Severity.allCases {
            for message in messages(severity: severity) {
                table.addRow([severity.symbol, message.message])
            }
        }
        return table.markdown()
    }
}
