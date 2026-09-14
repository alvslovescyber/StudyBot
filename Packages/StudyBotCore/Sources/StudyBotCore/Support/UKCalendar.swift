import Foundation

/// The one calendar the whole app uses (spec §4 "Dates, times and locale"). Locale `en-GB`,
/// time zone `Europe/London`, weeks starting Monday. Fixed, not configurable: the user is in
/// England for the whole three years.
///
/// Lives in Core rather than Kit because the server's Sunday digest and week arithmetic need
/// exactly the same calendar.
public enum UKCalendar {
    /// Europe/London. Constructed from the identifier, so a machine set to another zone
    /// still gets British time.
    public static let timeZone: TimeZone = {
        // The identifier is a fixed IANA name; if the platform ever lacked it, GMT is the
        // closest honest fallback and the tests would fail loudly on the BST cases.
        TimeZone(identifier: "Europe/London") ?? TimeZone(secondsFromGMT: 0) ?? .current
    }()

    public static let locale = Locale(identifier: "en_GB")

    /// Gregorian, en-GB, Europe/London, Monday first.
    public static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.locale = locale
        calendar.firstWeekday = 2  // Monday
        calendar.minimumDaysInFirstWeek = 4  // ISO 8601 week rule
        return calendar
    }()

    /// The instant at local midnight on the calendar day containing `date`.
    public static func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    /// Whether two instants fall on the same London calendar day.
    public static func isSameDay(_ a: Date, _ b: Date) -> Bool {
        calendar.isDate(a, inSameDayAs: b)
    }

    /// Whole calendar days from `from` to `to`, by calendar day rather than by interval, so a
    /// BST change never makes two midnights 23 or 25 hours apart look like a different count.
    /// Negative when `to` is before `from`.
    public static func days(from: Date, to: Date) -> Int {
        let components = calendar.dateComponents([.day], from: startOfDay(from), to: startOfDay(to))
        return components.day ?? 0
    }

    /// `date` shifted by `days` whole calendar days, at local midnight.
    public static func adding(days: Int, to date: Date) -> Date {
        let shifted = calendar.date(byAdding: .day, value: days, to: startOfDay(date))
        return startOfDay(shifted ?? date)
    }

    /// Whether the day is a Saturday or Sunday.
    public static func isWeekend(_ date: Date) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 || weekday == 7
    }

    /// The Monday 00:00 that begins the week containing `date` (§4: weeks start Monday).
    public static func startOfWeek(containing date: Date) -> Date {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return startOfDay(calendar.date(from: components) ?? date)
    }

    /// The Sunday that ends the week containing `date`, at local midnight.
    public static func endOfWeek(containing date: Date) -> Date {
        adding(days: 6, to: startOfWeek(containing: date))
    }
}
