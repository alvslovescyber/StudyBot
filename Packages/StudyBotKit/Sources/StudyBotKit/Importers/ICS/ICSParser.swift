import Foundation

/// A small, strict iCalendar tokenizer (RFC 5545). It turns bytes into a tree of
/// `ICSComponent`s and knows nothing about programme events; `ICSProgrammeCalendarReader`
/// gives the tree meaning.
///
/// Handles the traps §4 calls out: CRLF and bare LF line endings, **line unfolding**
/// (a line beginning with a space or tab continues the previous one), quoted parameter
/// values that may contain colons, and TEXT escapes via `ICSProperty.textValue`.
public enum ICSParser {
    public enum Error: Swift.Error, Equatable, Sendable {
        /// The bytes were not valid UTF-8.
        case notUTF8
        /// A content line had no `:` separating name from value. Carries the 1-based line number.
        case malformedLine(Int)
        /// An `END:` did not match the open component. Carries the expected and found names.
        case mismatchedEnd(expected: String, found: String)
        /// The file ended with components still open.
        case unterminatedComponent(String)
        /// Nothing at all, or no `BEGIN:VCALENDAR`.
        case noCalendar
    }

    /// Parses a whole file into its root `VCALENDAR` component.
    public static func parse(_ data: Data) throws(Error) -> ICSComponent {
        var bytes = data
        // Strip a UTF-8 byte-order mark if present; some exporters add one.
        if bytes.starts(with: [0xEF, 0xBB, 0xBF]) {
            bytes = bytes.dropFirst(3)
        }
        guard let text = String(data: bytes, encoding: .utf8) else {
            throw .notUTF8
        }
        return try parse(text)
    }

    /// Parses text into its root `VCALENDAR` component.
    public static func parse(_ text: String) throws(Error) -> ICSComponent {
        var state = ParseState()
        for (index, line) in unfold(text).enumerated() where !line.isEmpty {
            let property = try parseLine(line, number: index + 1)
            try state.consume(property)
        }
        if let open = state.stack.last {
            throw .unterminatedComponent(open.name)
        }
        guard let root = state.root else {
            throw .noCalendar
        }
        return root
    }

    /// The open-component stack while parsing, and the finished root once `END:VCALENDAR` is seen.
    private struct ParseState {
        var stack: [ICSComponent] = []
        var root: ICSComponent?

        mutating func consume(_ property: ICSProperty) throws(Error) {
            switch property.name {
            case "BEGIN":
                stack.append(ICSComponent(name: property.value.uppercased()))
            case "END":
                try end(property.value.uppercased())
            default:
                // A property outside any component is ignored rather than fatal; some files
                // carry stray lines before BEGIN:VCALENDAR.
                guard var current = stack.popLast() else { return }
                current.properties.append(property)
                stack.append(current)
            }
        }

        private mutating func end(_ name: String) throws(Error) {
            guard let finished = stack.popLast() else {
                throw .mismatchedEnd(expected: "", found: name)
            }
            guard finished.name == name else {
                throw .mismatchedEnd(expected: finished.name, found: name)
            }
            if var parent = stack.popLast() {
                parent.children.append(finished)
                stack.append(parent)
            } else if finished.name == "VCALENDAR", root == nil {
                root = finished
            }
        }
    }

    /// Splits text into logical lines, joining folded continuation lines (RFC 5545 §3.1):
    /// a CRLF or LF followed by a single space or tab is removed along with that character.
    public static func unfold(_ text: String) -> [String] {
        var lines: [String] = []
        for rawLine in text.split(
            omittingEmptySubsequences: false, whereSeparator: { $0 == "\n" || $0 == "\r\n" })
        {
            var line = Substring(rawLine)
            if line.hasSuffix("\r") { line = line.dropLast() }
            if let first = line.first, first == " " || first == "\t", !lines.isEmpty {
                lines[lines.count - 1].append(contentsOf: line.dropFirst())
            } else {
                lines.append(String(line))
            }
        }
        return lines
    }

    /// Splits `NAME;P=v;Q="a:b":VALUE` into its parts, honouring quotes around parameter values.
    static func parseLine(_ line: String, number: Int) throws(Error) -> ICSProperty {
        var inQuotes = false
        var separator: String.Index?
        for index in line.indices {
            let character = line[index]
            if character == "\"" {
                inQuotes.toggle()
            } else if character == ":" && !inQuotes {
                separator = index
                break
            }
        }
        guard let separator else {
            throw .malformedLine(number)
        }

        let head = line[..<separator]
        let value = String(line[line.index(after: separator)...])

        var headParts = splitOutsideQuotes(head, on: ";")
        let name = headParts.removeFirst().uppercased()
        var parameters: [String: String] = [:]
        for part in headParts {
            let pieces = part.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            let key = String(pieces[0]).uppercased()
            let rawValue = pieces.count > 1 ? String(pieces[1]) : ""
            parameters[key] = rawValue.replacingOccurrences(of: "\"", with: "")
        }
        return ICSProperty(name: name, parameters: parameters, value: value)
    }

    private static func splitOutsideQuotes(_ text: Substring, on delimiter: Character) -> [Substring] {
        var parts: [Substring] = []
        var inQuotes = false
        var start = text.startIndex
        for index in text.indices {
            let character = text[index]
            if character == "\"" {
                inQuotes.toggle()
            } else if character == delimiter && !inQuotes {
                parts.append(text[start..<index])
                start = text.index(after: index)
            }
        }
        parts.append(text[start...])
        return parts
    }
}
