import Arguments
import Foundation

struct PullRequestOption: ExpressibleByArgument {
    let owner: String
    let repository: String
    let number: Int

    init?(argument: String) {
        guard let url = URL(string: argument) else {
            return nil
        }

        guard url.host == "github.com" else {
            return nil
        }

        var path = url.pathComponents.dropFirst()

        guard let owner = path.popFirst() else {
            return nil
        }

        guard let repository = path.popFirst() else {
            return nil
        }

        guard path.popFirst() == "pull" else {
            return nil
        }

        guard let numberString = path.popFirst(), let number = Int(numberString) else {
            return nil
        }

        self.owner = owner
        self.repository = repository
        self.number = number
    }
}

extension Array {
    mutating func popFirst() -> Element? {
        guard !isEmpty else {
            return nil
        }

        return removeFirst()
    }
}
