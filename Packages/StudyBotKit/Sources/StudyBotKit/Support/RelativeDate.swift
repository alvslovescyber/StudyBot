import Foundation
import StudyBotCore

/// The only place dates become words (spec §3.13, §4). Under 14 days away the result is
/// relative ("in 11 days"); beyond that it is absolute ("15 Oct"), with the year shown only
/// when it is not the current one ("15 Oct 2027"). Everything is en-GB, Europe/London.
///
/// Takes `now` explicitly so tests are deterministic and so a view never reaches for the
/// clock itself.
public enum RelativeDate {
    /// The number of days at which wording switches from relative to absolute.
    public static let relativeHorizonDays = 14

    /// "today", "tomorrow", "yesterday", "in 11 days", "3 days ago", "15 Oct", "15 Oct 2027".
    public static func string(for date: Date, relativeTo now: Date) -> String {
        let days = UKCalendar.days(from: now, to: date)
        switch days {
        case 0: return "today"
        case 1: return "tomorrow"
        case -1: return "yesterday"
        case 2..<relativeHorizonDays: return "in \(days) days"
        case (-relativeHorizonDays + 1)...(-2): return "\(-days) days ago"
        default: return absolute(date, relativeTo: now)
        }
    }

    /// Deadline wording for a due date (§6.1): "due today", "due tomorrow", "due in 12 days",
    /// "overdue by 3 days", or "due 15 Oct" once beyond the relative horizon. Overdue items
    /// always stay relative because "overdue by" is the whole point of the label.
    public static func deadline(_ dueDate: Date, relativeTo now: Date) -> String {
        let days = UKCalendar.days(from: now, to: dueDate)
        switch days {
        case 0: return "due today"
        case 1: return "due tomorrow"
        case -1: return "overdue by 1 day"
        case ..<(-1): return "overdue by \(-days) days"
        case 2..<relativeHorizonDays: return "due in \(days) days"
        default: return "due \(absolute(dueDate, relativeTo: now))"
        }
    }

    /// "15 Oct", or "15 Oct 2027" when the year differs from `now`'s.
    public static func absolute(_ date: Date, relativeTo now: Date) -> String {
        let calendar = UKCalendar.calendar
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
        return (sameYear ? shortFormatter : shortWithYearFormatter).string(from: date)
    }

    /// "Wednesday 23 September", for the Today header.
    public static func longDay(_ date: Date) -> String {
        longDayFormatter.string(from: date)
    }

    /// A range of days: "22–24 Sept" within one month, "30 Sept – 2 Oct" across months, the
    /// year added only when it differs from `now`'s. A single day is just that day.
    public static func dayRange(_ start: Date, _ end: Date, relativeTo now: Date) -> String {
        let calendar = UKCalendar.calendar
        if UKCalendar.isSameDay(start, end) {
            return absolute(start, relativeTo: now)
        }
        let sameMonth = calendar.isDate(start, equalTo: end, toGranularity: .month)
        if sameMonth {
            let day = calendar.component(.day, from: start)
            return "\(day)–\(absolute(end, relativeTo: now))"
        }
        return "\(absolute(start, relativeTo: now)) – \(absolute(end, relativeTo: now))"
    }

    /// "Tue", for a block day's column header.
    public static func weekday(_ date: Date) -> String {
        weekdayFormatter.string(from: date)
    }

    /// "19:44", for a sync time in Settings. 24-hour, as en-GB is.
    public static func time(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    /// "15 October 2026": the unabbreviated form, always with the year, for text that is
    /// stored rather than displayed relative to now (the calendar-created assignment titles).
    public static func fullDate(_ date: Date) -> String {
        fullDateFormatter.string(from: date)
    }

    /// Working days as words (§9 "Working-days-until rather than raw days"): "21 working days",
    /// "1 working day", or "no working days left" once the deadline is today or past.
    public static func workingDays(_ count: Int) -> String {
        switch count {
        case ..<1: return "no working days left"
        case 1: return "1 working day"
        default: return "\(count) working days"
        }
    }

    /// A word count with a thousands separator, en-GB: "2,500 words", "1 word".
    public static func wordCount(_ count: Int) -> String {
        let number = count.formatted(.number.locale(UKCalendar.locale))
        return count == 1 ? "\(number) word" : "\(number) words"
    }

    private static let shortFormatter = makeFormatter("d MMM")
    private static let shortWithYearFormatter = makeFormatter("d MMM yyyy")
    private static let longDayFormatter = makeFormatter("EEEE d MMMM")
    private static let fullDateFormatter = makeFormatter("d MMMM yyyy")
    private static let timeFormatter = makeFormatter("HH:mm")
    private static let weekdayFormatter = makeFormatter("EEE")

    private static func makeFormatter(_ pattern: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = UKCalendar.calendar
        formatter.locale = UKCalendar.locale
        formatter.timeZone = UKCalendar.timeZone
        formatter.dateFormat = pattern
        return formatter
    }
}
