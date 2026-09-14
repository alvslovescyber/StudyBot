import Foundation
import StudyBotCore
import StudyBotKit
import Testing

@Suite("WorkingDays — §3.12 row 2")
struct WorkingDaysTests {
    private func d(_ y: Int, _ m: Int, _ d: Int) -> LocalDay { RealCalendar.day(y, m, d) }

    @Test("excludes weekends, bank holidays, closures and campus days, all from the calendar")
    func exclusions() throws {
        let working = WorkingDays(events: try RealCalendar.events())
        #expect(working.isWorkingDay(d(2026, 9, 21)))  // Monday before induction
        #expect(!working.isWorkingDay(d(2026, 9, 22)))  // induction: a campus day
        #expect(!working.isWorkingDay(d(2026, 9, 23)))  // Block 1
        #expect(!working.isWorkingDay(d(2026, 9, 24)))  // Block 1
        #expect(working.isWorkingDay(d(2026, 9, 25)))  // Friday after the block: DTEND was exclusive
        #expect(!working.isWorkingDay(d(2026, 9, 26)))  // Saturday
        #expect(!working.isWorkingDay(d(2026, 12, 25)))  // Christmas Day bank holiday
        #expect(!working.isWorkingDay(d(2026, 12, 22)))  // university closure
        #expect(working.isWorkingDay(d(2027, 4, 20)))  // reading week is a working day
        #expect(working.isWorkingDay(d(2026, 10, 15)))  // a deadline day is a working day
        #expect(working.blockingKind(on: d(2026, 9, 22)) == .induction)
        #expect(working.blockingKind(on: d(2026, 12, 22)) == .closure)
        #expect(working.blockingKind(on: d(2027, 5, 3)) == .bankHoliday)
        #expect(working.blockingKind(on: d(2026, 9, 26)) == nil)
    }

    @Test("the milestone-one acceptance case: 20 Dec 2026 to 11 Jan 2027 has 2 working days")
    func acrossChristmasAndBlockTwo() throws {
        // 20 Dec Sun · 21–24 closure · 25 BH · 26–27 weekend · 28 BH · 29–31 closure ·
        // 1 Jan BH · 2–3 weekend · 4–6 Block 2 · 7 Thu ✓ · 8 Fri ✓ · 9–10 weekend · 11 = deadline.
        let working = WorkingDays(events: try RealCalendar.events())
        #expect(working.count(from: d(2026, 12, 20), until: d(2027, 1, 11)) == 2)
        #expect(working.workingDays(in: d(2026, 12, 20)...d(2027, 1, 10)) == [d(2027, 1, 7), d(2027, 1, 8)])
    }

    @Test("counts across a term boundary: mid-July to the first Y2 session")
    func acrossTermBoundary() throws {
        // 15 Jul 2027 (Thu) to 28 Sep 2027 (Tue). Calendar days: 75.
        // Weekdays in [15 Jul, 28 Sep): 53. Minus 30 Aug bank holiday, minus Block 4 (21–22 Sep) = 50.
        let working = WorkingDays(events: try RealCalendar.events())
        #expect(d(2027, 7, 15).days(until: d(2027, 9, 28)) == 75)
        #expect(working.count(from: d(2027, 7, 15), until: d(2027, 9, 28)) == 50)
    }

    @Test("a deadline today or in the past gives 0, never a negative number")
    func neverNegative() throws {
        let working = WorkingDays(events: try RealCalendar.events())
        #expect(working.count(from: d(2026, 10, 15), until: d(2026, 10, 15)) == 0)
        #expect(working.count(from: d(2026, 10, 20), until: d(2026, 10, 15)) == 0)
        #expect(working.count(from: d(2029, 12, 1), until: d(2026, 1, 1)) == 0)
    }

    @Test("the working days before the first deadline, from the day after induction week")
    func firstDeadline() throws {
        // Mon 28 Sep → Thu 15 Oct 2026: weekdays 28,29,30 Sep, 1,2, 5–9, 12–14 Oct = 13. No holidays.
        let working = WorkingDays(events: try RealCalendar.events())
        #expect(working.count(from: d(2026, 9, 28), until: d(2026, 10, 15)) == 13)
        // From induction day itself: 25 Sep is the only extra working day that week.
        #expect(working.count(from: d(2026, 9, 22), until: d(2026, 10, 15)) == 14)
    }

    @Test("stepping by working days skips weekends and blocked days in both directions")
    func stepping() throws {
        let working = WorkingDays(events: try RealCalendar.events())
        // One step from the Monday jumps over induction and Block 1 to the Friday.
        #expect(working.adding(workingDays: 1, to: d(2026, 9, 21)) == d(2026, 9, 25))
        #expect(working.adding(workingDays: -1, to: d(2027, 1, 7)) == d(2026, 12, 18))  // back over Christmas
        #expect(working.adding(workingDays: 0, to: d(2026, 12, 25)) == d(2026, 12, 25))
        #expect(working.adding(workingDays: 2, to: d(2026, 10, 15)) == d(2026, 10, 19))  // Thu → Mon
        #expect(working.nextWorkingDay(onOrAfter: d(2026, 12, 20)) == d(2027, 1, 7))
        #expect(working.previousWorkingDay(onOrBefore: d(2027, 1, 6)) == d(2026, 12, 18))
        #expect(working.nextWorkingDay(onOrAfter: d(2026, 10, 15)) == d(2026, 10, 15))
    }

    @Test("a cancelled event no longer blocks a day; an empty calendar blocks only weekends")
    func cancelledAndEmpty() throws {
        var events = try RealCalendar.events()
        let index = try #require(events.firstIndex { $0.kind == .induction })
        events[index].cancelledAt = Date()
        let working = WorkingDays(events: events)
        #expect(working.isWorkingDay(d(2026, 9, 22)))
        #expect(!working.isWorkingDay(d(2026, 9, 23)))

        let empty = WorkingDays(events: [])
        #expect(empty.isWorkingDay(d(2026, 12, 25)))
        #expect(!empty.isWorkingDay(d(2026, 12, 26)))
        #expect(empty.count(from: d(2026, 12, 21), until: d(2026, 12, 28)) == 5)
    }
}
