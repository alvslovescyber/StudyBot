import Foundation

/// A calendar date with no time, in the London calendar: `2026-09-23`.
///
/// Models store date-only values as `Date` at local midnight (§4). This type is the
/// conversion and arithmetic helper that keeps those `Date`s honest: the ICS importer
/// parses `20260923` into a `LocalDay`, the store keeps `day.date`, and comparisons go
/// through calendar-day arithmetic rather than seconds.
public struct LocalDay: Hashable, Sendable, Comparable, Codable, CustomStringConvertible {
    public var year: Int
    public var month: Int
    public var day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// The London calendar day containing `date`.
    public init(_ date: Date) {
        let components = UKCalendar.calendar.dateComponents([.year, .month, .day], from: date)
        self.year = components.year ?? 1970
        self.month = components.month ?? 1
        self.day = components.day ?? 1
    }

    /// Parses `yyyy-MM-dd` or the ICS form `yyyyMMdd`. Nil for anything else, including an
    /// impossible date such as 31 February.
    public init?(iso text: String) {
        let digits = text.filter(\.isNumber)
        guard digits.count == 8,
            text.count == 8 || (text.count == 10 && text.split(separator: "-").count == 3),
            let year = Int(digits.prefix(4)),
            let month = Int(digits.dropFirst(4).prefix(2)),
            let day = Int(digits.suffix(2))
        else { return nil }
        self.init(year: year, month: month, day: day)
        guard isValid else { return nil }
    }

    /// Whether the components name a real Gregorian date.
    public var isValid: Bool {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        guard let date = UKCalendar.calendar.date(from: components) else { return false }
        return LocalDay(date) == self
    }

    /// The instant at Europe/London midnight on this day. This is what models store.
    public var date: Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 0
        components.minute = 0
        components.second = 0
        // Components built from a valid LocalDay always resolve; the fallback is unreachable
        // for valid days and exists only to avoid a force unwrap.
        return UKCalendar.calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }

    /// `yyyy-MM-dd`.
    public var isoString: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    public var description: String { isoString }

    /// This day shifted by `days`.
    public func adding(days: Int) -> LocalDay {
        LocalDay(UKCalendar.adding(days: days, to: date))
    }

    /// Whole days from `self` to `other`; negative when `other` is earlier.
    public func days(until other: LocalDay) -> Int {
        UKCalendar.days(from: date, to: other.date)
    }

    /// Saturday or Sunday.
    public var isWeekend: Bool { UKCalendar.isWeekend(date) }

    /// 1 = Monday … 7 = Sunday.
    public var isoWeekday: Int {
        let weekday = UKCalendar.calendar.component(.weekday, from: date)  // 1 = Sunday
        return weekday == 1 ? 7 : weekday - 1
    }

    public static func < (lhs: LocalDay, rhs: LocalDay) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    // MARK: Codable as a plain "yyyy-MM-dd" string

    public init(from decoder: any Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        guard let day = LocalDay(iso: text) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath, debugDescription: "Not a yyyy-MM-dd date: \(text)"))
        }
        self = day
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(isoString)
    }
}

extension ClosedRange where Bound == LocalDay {
    /// Every day in the range, in order.
    public var days: [LocalDay] {
        var result: [LocalDay] = []
        var current = lowerBound
        while current <= upperBound {
            result.append(current)
            current = current.adding(days: 1)
        }
        return result
    }
}
