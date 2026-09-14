import Foundation
import StudyBotCore

/// Working-day arithmetic over the programme calendar (spec §4 "Dates, times and locale",
/// §4A "Derived signals"). A working day is a weekday that is not a bank holiday, a
/// university closure or an on-campus day, and every one of those comes from the imported
/// events. Nothing here is hardcoded.
///
/// "Nine working days" is the honest number before a deadline; "twenty-three days" is not.
public struct WorkingDays: Sendable {
    /// Days that are not working days for a calendar reason, with the reason.
    public let blockedDays: [LocalDay: EventKind]

    /// Builds the blocked-day set from every non-cancelled event whose kind blocks a
    /// working day (`EventKind.blocksWorkingDay`).
    public init(events: [ProgrammeEvent]) {
        var blocked: [LocalDay: EventKind] = [:]
        for event in events where !event.isCancelled && event.kind.blocksWorkingDay {
            for day in (LocalDay(event.startDate)...LocalDay(event.endDate)).days {
                // Campus days outrank the rest so the UI can say "on campus" over "closure"
                // if both ever coincide; otherwise first writer wins.
                if event.kind.isCampusDay || blocked[day] == nil {
                    blocked[day] = event.kind
                }
            }
        }
        self.blockedDays = blocked
    }

    /// Whether `day` is a working day: not a weekend and not blocked by the calendar.
    public func isWorkingDay(_ day: LocalDay) -> Bool {
        !day.isWeekend && blockedDays[day] == nil
    }

    /// Why `day` is not a working day, or nil if it is one. Weekends report nil here; check
    /// `LocalDay.isWeekend` for those.
    public func blockingKind(on day: LocalDay) -> EventKind? {
        blockedDays[day]
    }

    /// Working days in `[start, deadline)`: the days you can still work on something due on
    /// `deadline`, counting `start` itself if it is a working day and never counting the
    /// deadline day. Returns 0, never a negative number, when the deadline is today or past.
    public func count(from start: LocalDay, until deadline: LocalDay) -> Int {
        guard deadline > start else { return 0 }
        var total = 0
        var day = start
        while day < deadline {
            if isWorkingDay(day) { total += 1 }
            day = day.adding(days: 1)
        }
        return total
    }

    /// `count(from:until:)` for instants, by London calendar day.
    public func count(from start: Date, until deadline: Date) -> Int {
        count(from: LocalDay(start), until: LocalDay(deadline))
    }

    /// The first working day on or after `day`.
    public func nextWorkingDay(onOrAfter day: LocalDay) -> LocalDay {
        var candidate = day
        while !isWorkingDay(candidate) {
            candidate = candidate.adding(days: 1)
        }
        return candidate
    }

    /// The last working day on or before `day`.
    public func previousWorkingDay(onOrBefore day: LocalDay) -> LocalDay {
        var candidate = day
        while !isWorkingDay(candidate) {
            candidate = candidate.adding(days: -1)
        }
        return candidate
    }

    /// The day reached by stepping `count` working days from `day`. Positive counts step
    /// forward, negative backward; zero returns `day` unchanged. The starting day itself is
    /// not counted as a step. This is what the work-back plan uses to place milestones.
    public func adding(workingDays count: Int, to day: LocalDay) -> LocalDay {
        guard count != 0 else { return day }
        let direction = count > 0 ? 1 : -1
        var remaining = abs(count)
        var candidate = day
        while remaining > 0 {
            candidate = candidate.adding(days: direction)
            if isWorkingDay(candidate) { remaining -= 1 }
        }
        return candidate
    }

    /// Every working day in `range`, in order.
    public func workingDays(in range: ClosedRange<LocalDay>) -> [LocalDay] {
        range.days.filter(isWorkingDay)
    }
}
