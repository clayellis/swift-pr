public struct MarkdownTable {
    public enum Alignment {
        case left
        case center
        case right

        func markdown(length: Int? = nil) -> String {
            if let length {
                switch self {
                case .left:
                    return ":-".padding(toLength: length, withPad: "-")
                case .center:
                    return ":-".padding(toLength: length - 1, withPad: "-") + ":"
                case .right:
                    return "-".padding(toLength: length - 1, withPad: "-") + ":"
                }
            } else {
                switch self {
                case .left:
                    return ":-"
                case .center:
                    return ":-:"
                case .right:
                    return "-:"
                }
            }
        }
    }

    private var columns: [(String, Alignment)]
    private var rows: [[String]]

    init(columns: [(String, Alignment)] = [(String, Alignment)](), rows: [[String]] = [[String]]()) {
        self.columns = columns
        self.rows = rows
    }

    mutating func setColumns(_ columns: [(String, Alignment)]) {
        rows = []
        self.columns = columns
    }

    mutating func addRow(_ row: [String]) {
        rows.append(row)
    }

    func markdown(compact: Bool = false) -> String {
        let padding = compact ? "" : " "
        let separator = "\(padding)|\(padding)"

        var columnWidths = Array(repeating: 0, count: columns.count)

        for (index, column) in zip(columns.indices, columns) {
            columnWidths[index] = max(column.0.count, columnWidths[index])
            columnWidths[index] = max(column.1.markdown().count, columnWidths[index])
        }

        for row in rows {
            for (columnIndex, column) in zip(row.indices, row) {
                columnWidths[columnIndex] = max(column.count, columnWidths[columnIndex])
            }
        }

        return """
        |\(padding)\(zip(columns.indices, columns).map { compact ? $0.1.0 : $0.1.0.padding(toLength: columnWidths[$0.0], withPad: " ") }.joined(separator: separator))\(padding)|
        |\(padding)\(zip(columns.indices, columns).map { compact ? $0.1.1.markdown() : $0.1.1.markdown(length: columnWidths[$0.0]) }.joined(separator: separator))\(padding)|
        \(rows.map { row in "|\(padding)" + zip(row.indices, row).map { compact ? $0.1 : $0.1.padding(toLength: columnWidths[$0.0], withPad: " ") }.joined(separator: separator) + "\(padding)|" }.joined(separator: "\n"))
        """
    }
}

extension Array<(String, MarkdownTable.Alignment)>: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, MarkdownTable.Alignment)...) {
        self = elements
    }
}

extension String {
    func padding(toLength length: Int, withPad pad: String) -> String {
        self.padding(toLength: length, withPad: pad, startingAt: 0)
    }
}
