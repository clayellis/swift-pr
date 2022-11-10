import Foundation

public extension FileManager {
    func contents(of filePath: String) -> String? {
        let relativePath = "\(currentDirectoryPath.removingSuffix("/"))/\(filePath.removingSuffix("/"))"
        PR.shared.verboseLog("Getting contents of: \(relativePath)")

        guard fileExists(atPath: relativePath) else {
            PR.shared.log("File doesn't exist at: \(relativePath)")
            return nil
        }

        if !isReadableFile(atPath: relativePath) {
            PR.shared.log("Cannot read contents of: \(relativePath)")
        }

        let contents = contents(atPath: relativePath).map { String(decoding: $0, as: UTF8.self) }

        if contents == nil {
            PR.shared.log("Contents were nil")
        }

        return contents
    }
}
