import Foundation
import StudyBotCore
import StudyBotKit
import Testing

@Suite("RelativeDate — §4 formatting rules")
struct RelativeDateTests {
    // Monday 14 September 2026, mid-morning London time.
    private let now = LocalDay(year: 2026, month: 9, day: 14).date.addingTimeInterval(10 * 3_600)

    private func day(_ month: Int, _ day: Int, _ year: Int = 2026) -> Date {
        LocalDay(year: year, month: month, day: day).date
    }

    @Test("under 14 days is relative")
    func relative() {
        #expect(RelativeDate.string(for: day(9, 14), relativeTo: now) == "today")
        #expect(RelativeDate.string(for: day(9, 15), relativeTo: now) == "tomorrow")
        #expect(RelativeDate.string(for: day(9, 13), relativeTo: now) == "yesterday")
        #expect(RelativeDate.string(for: day(9, 22), relativeTo: now) == "in 8 days")
        #expect(RelativeDate.string(for: day(9, 27), relativeTo: now) == "in 13 days")
        #expect(RelativeDate.string(for: day(9, 11), relativeTo: now) == "3 days ago")
    }

    @Test("14 days or more is absolute, with the year only when it differs")
    func absolute() {
        #expect(RelativeDate.string(for: day(11, 28), relativeTo: now) == "28 Nov")
        #expect(RelativeDate.string(for: day(10, 15), relativeTo: now) == "15 Oct")
        #expect(RelativeDate.string(for: day(7, 1, 2027), relativeTo: now) == "1 Jul 2027")
        #expect(RelativeDate.string(for: day(1, 4, 2026), relativeTo: now) == "4 Jan")
    }

    @Test("deadline wording says overdue by, and stays relative when overdue")
    func deadlines() {
        #expect(RelativeDate.deadline(day(9, 14), relativeTo: now) == "due today")
        #expect(RelativeDate.deadline(day(9, 15), relativeTo: now) == "due tomorrow")
        #expect(RelativeDate.deadline(day(9, 26), relativeTo: now) == "due in 12 days")
        #expect(RelativeDate.deadline(day(9, 13), relativeTo: now) == "overdue by 1 day")
        #expect(RelativeDate.deadline(day(9, 1), relativeTo: now) == "overdue by 13 days")
        #expect(RelativeDate.deadline(day(8, 1), relativeTo: now) == "overdue by 44 days")
        #expect(RelativeDate.deadline(day(10, 15), relativeTo: now) == "due 15 Oct")
        #expect(RelativeDate.deadline(day(7, 20, 2027), relativeTo: now) == "due 20 Jul 2027")
    }

    @Test("the day count is by London calendar day, so an evening now does not shift it")
    func eveningNow() {
        let lateEvening = LocalDay(year: 2026, month: 9, day: 14).date.addingTimeInterval(
            23 * 3_600 + 30 * 60)
        #expect(RelativeDate.string(for: day(9, 15), relativeTo: lateEvening) == "tomorrow")
        #expect(RelativeDate.string(for: day(9, 22), relativeTo: lateEvening) == "in 8 days")
    }

    @Test("the Today header is the long British form")
    func longDay() {
        #expect(RelativeDate.longDay(day(9, 14)) == "Monday 14 September")
        #expect(RelativeDate.longDay(day(9, 23)) == "Wednesday 23 September")
        #expect(RelativeDate.fullDate(day(10, 15)) == "15 October 2026")
    }
}
