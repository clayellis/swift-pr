import Foundation
import OctoKit
import SwiftEnvironment

public class PR {
    internal static let shared = PR()

    // The combined results (output) of all checks run on this PR.
    internal var results = Results()

    // The output being built up by the current check on this PR.
    internal var output = Output()

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
    struct Output: Codable {
        var checkName: String?
        var messages = [Message]()
        var markdowns = [String]()

        var markdown: String {
            """
            \(messagesMarkdown)

            \(markdowns.joined(separator: "\n\n"))
            """
        }

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

        func messages(severity: Message.Severity) -> [Message] {
            messages.filter { $0.severity == severity }
        }
    }

    struct Results: Codable {
        var output = [Output]()

        var markdown: String {
            if output.count == 1 {
                return output[0].markdown
            } else {
                var markdown = ""
                for output in output {
                    markdown += """

                    #### \(output.checkName ?? "Unnamed Check")
                    \(output.markdown)

                    """
                }
                return markdown
            }
        }

        func json() throws -> String {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted]
            let data = try encoder.encode(self)
            return String(decoding: data, as: UTF8.self)
        }
    }
}

extension PR {
    public func markdown(_ markdown: String) {
        self.output.markdowns.append(markdown)
    }
}
