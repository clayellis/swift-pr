import Foundation

public struct Diff {
    public private(set) var created = [String]()
    public private(set) var deleted = [String]()
    public private(set) var modified = [String]()
    public private(set) var renamed = [(from: String, to: String)]()
}

extension Diff {
    init(owner: String, repository: String, number: Int, token: String) async throws {
        let diffURL = URL(string: "https://api.github.com/repos/\(owner)/\(repository)/pulls/\(number)")!
        var diffRequest = URLRequest(url: diffURL)
        diffRequest.allHTTPHeaderFields = [
            "Accept": "application/vnd.github.v3.diff",
            "Authorization": "Bearer \(token)"
        ]
        let diffData = try await URLSession.shared.data(for: diffRequest).0
        let diffString = String(decoding: diffData, as: UTF8.self)
        self.init(diffString: diffString)
    }

    init(diffString: String) {
        self.init()

        let headers = diffString.components(separatedBy: "diff --git")

        for header in headers {
            let lines = header.components(separatedBy: "\n")

            guard let firstLine = lines.first, firstLine.hasPrefix(" a/") else {
                continue
            }

            guard let filePath = firstLine.components(separatedBy: " b/").last else {
                continue
            }

            if lines.contains(where: { $0.hasPrefix("new file mode ") }) {
                self.created.append(filePath)
            } else if lines.contains(where: { $0.hasPrefix("delete file mode ") }) {
                self.deleted.append(filePath)
            } else if let renameFromLine = lines.firstIndex(where: { $0.hasPrefix("rename from ") }) {
                let from = lines[renameFromLine].removingPrefix("rename from ")
                self.renamed.append((from: from, to: filePath))
            } else {
                self.modified.append(filePath)
            }
        }
    }
}
