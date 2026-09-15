import Foundation

/// The one JSON configuration for everything that crosses the wire, so client and server
/// cannot disagree about date format or key style.
///
/// Dates are ISO 8601 in UTC, as in the §3.5 example (`"2026-10-02T19:44:10Z"`). A date with
/// a fractional second is written with milliseconds (`"…:10.250Z"`) rather than truncated:
/// `updatedAt` decides last-write-wins, and two edits inside the same second on two Macs must
/// not tie. Decoding accepts both forms.
public enum SyncCoding {
    public static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(string(from: date))
        }
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    public static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            guard let date = date(from: text) else {
                throw DecodingError.dataCorruptedError(
                    in: container, debugDescription: "Not an ISO 8601 date: \(text)")
            }
            return date
        }
        return decoder
    }

    public static func encode<T: Encodable>(_ value: T) throws -> Data {
        try makeEncoder().encode(value)
    }

    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try makeDecoder().decode(type, from: data)
    }

    // MARK: Dates

    private static let wholeSeconds = Date.ISO8601FormatStyle(includingFractionalSeconds: false)
    private static let fractionalSeconds = Date.ISO8601FormatStyle(includingFractionalSeconds: true)

    /// `2026-10-02T19:44:10Z`, or `2026-10-02T19:44:10.250Z` when the date has a fractional part.
    public static func string(from date: Date) -> String {
        let milliseconds = (date.timeIntervalSince1970 * 1_000).rounded()
        let isWhole = milliseconds.truncatingRemainder(dividingBy: 1_000) == 0
        return isWhole ? wholeSeconds.format(date) : fractionalSeconds.format(date)
    }

    /// Parses either form. Nil for anything that is not ISO 8601.
    public static func date(from text: String) -> Date? {
        (try? fractionalSeconds.parse(text)) ?? (try? wholeSeconds.parse(text))
    }
}
