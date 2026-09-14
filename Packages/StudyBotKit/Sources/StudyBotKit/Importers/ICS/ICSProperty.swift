/// One content line of an iCalendar file after unfolding (RFC 5545 §3.1):
/// `NAME;PARAM=value;PARAM2="quoted":VALUE`.
public struct ICSProperty: Hashable, Sendable {
    /// Upper-cased property name, e.g. `DTSTART`.
    public var name: String
    /// Parameters with upper-cased names, e.g. `["VALUE": "DATE"]`. Quotes are removed.
    public var parameters: [String: String]
    /// The raw value, exactly as written after the colon. Escapes are **not** processed;
    /// use `textValue` for TEXT properties.
    public var value: String

    public init(name: String, parameters: [String: String] = [:], value: String) {
        self.name = name
        self.parameters = parameters
        self.value = value
    }

    /// The value with RFC 5545 §3.3.11 TEXT escapes resolved: `\n` and `\N` become a newline,
    /// `\,` `\;` and `\\` become the literal character.
    public var textValue: String {
        ICSProperty.unescapeText(value)
    }

    /// A parameter by name, case-insensitively.
    public subscript(parameter name: String) -> String? {
        parameters[name.uppercased()]
    }

    static func unescapeText(_ raw: String) -> String {
        var result = ""
        result.reserveCapacity(raw.count)
        var iterator = raw.makeIterator()
        while let character = iterator.next() {
            guard character == "\\" else {
                result.append(character)
                continue
            }
            guard let next = iterator.next() else {
                // A trailing lone backslash is kept as-is rather than dropped.
                result.append(character)
                break
            }
            switch next {
            case "n", "N": result.append("\n")
            case ",": result.append(",")
            case ";": result.append(";")
            case "\\": result.append("\\")
            default:
                // Not a defined escape: keep both characters so nothing is silently lost.
                result.append(character)
                result.append(next)
            }
        }
        return result
    }
}
