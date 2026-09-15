import Foundation
import StudyBotCore

/// Day comparisons for views, by London calendar day (spec §4).
enum UKCalendarDays {
    /// Whether `date` falls on a day before `now`'s day.
    static func isPast(_ date: Date, relativeTo now: Date) -> Bool {
        UKCalendar.days(from: now, to: date) < 0
    }
}
