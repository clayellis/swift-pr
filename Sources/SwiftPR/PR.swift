import Foundation
import OctoKit
import SwiftEnvironment

public class PR {
    internal static let shared = PR()

    // The output being built up by the current check on this PR.
    public var output: Output!

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
    public struct Output: Codable {
        static let startTag = "<!--__output-start__"
        static let endTag = "__output-end__-->"

        var checkName: String
        var messages = [Message]()
        var markdowns = [String]()

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

        var markdown: String {
            """
            #### \(checkName)

            \(messagesMarkdown)

            \(markdowns.joined(separator: "\n\n"))
            """
        }

        func messages(severity: Message.Severity) -> [Message] {
            messages.filter { $0.severity == severity }
        }

        func json() throws -> String {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted]
            let data = try encoder.encode(self)
            return String(decoding: data, as: UTF8.self)
        }

        func body() throws -> String {
            """
            \(Self.startTag)
            \(try json())
            \(Self.endTag)

            \(markdown)
            """
        }
    }
}

public extension Comment {
    func swiftPROutput() throws -> PR.Output? {
        guard let start = body.range(of: PR.Output.startTag), let end = body.range(of: PR.Output.endTag) else {
            return nil
        }

        let results = body[body.index(after: start.upperBound)..<end.lowerBound]
        let output = try JSONDecoder().decode(PR.Output.self, from: Data(results.utf8))
        return output
    }
}

extension PR.Output {
    public mutating func markdown(_ markdown: String) {
        markdowns.append(markdown)
    }
}
