import Foundation
import StudyBotCore
import StudyBotKit
import Testing

/// The term strip's data against the real calendar: before induction, mid-term, and its
/// spoken summary.
@Suite("TermStrip — the current term as one line")
struct TermStripTests {
    private func strip(on day: LocalDay) throws -> TermStrip {
        let events = try RealCalendar.events()
        let calendar = TermCalendar(events: events, derivedAt: RealCalendar.importedAt)
        let submissions = events.filter { $0.kind == .assignment }.map(\.startDate)
        return try #require(
            TermStrip(calendar: calendar, events: events, submissionDates: submissions, today: day))
    }

    @Test("before induction the strip shows term 1, starting in 7 days, with three submissions")
    func beforeTerm() throws {
        let strip = try strip(on: RealCalendar.day(2026, 9, 15))
        #expect(strip.term.year == 1 && strip.term.number == 1)
        #expect(strip.title == "Term 1")
        #expect(strip.caption == "starts in 7 days")
        #expect(strip.todayPosition == nil)
        #expect(strip.marks.filter { $0.kind == .submission }.count == 3)
        #expect(strip.marks.filter { $0.kind == .block }.count == 1, "Block 1 sits in term 1")
        #expect(strip.marks.first?.kind == .block)
        #expect(strip.marks.first?.start == 0, "the term starts with induction")
        #expect(strip.daysToNextSubmission == 30)
        #expect(strip.summary == "Term 1, starts in 7 days. Next submission in 30 days.")
    }

    @Test("every mark says what it is; a Monday session is coloured only when it names one module")
    func labelsAndColours() throws {
        let events = try RealCalendar.events()
        let calendar = TermCalendar(events: events, derivedAt: RealCalendar.importedAt)
        let submissions = events.filter { $0.kind == .assignment }.map(\.startDate)
        let today = RealCalendar.day(2026, 9, 15)
        // The real calendar names a whole term's modules on every Monday session, so on real
        // data no tick is coloured: the strip stays honest rather than guessing a module.
        #expect(events.allSatisfy { $0.kind != .online || $0.moduleCodes.count != 1 })
        let real = try #require(
            TermStrip(
                calendar: calendar, events: events, submissionDates: submissions, today: today,
                moduleColours: ["COM1018DA": .teal]))
        // "Sep" or "Sept" depends on the ICU build, so the expectation is built the same way.
        let blockDates = RelativeDate.dayRange(
            RealCalendar.day(2026, 9, 22).date, RealCalendar.day(2026, 9, 24).date, relativeTo: today.date)
        #expect(real.marks.first?.label == "Block 1, \(blockDates)")
        #expect(real.marks.filter { $0.kind == .session }.allSatisfy { $0.moduleColour == nil })
        let monday = try #require(real.marks.first { $0.kind == .session })
        let mondayEvent = try #require(events.first { LocalDay($0.startDate) == monday.day && $0.kind == .online })
        #expect(monday.label == "\(mondayEvent.title), \(RelativeDate.absolute(monday.day.date, relativeTo: today.date))")
        let submission = try #require(real.marks.first { $0.kind == .submission })
        #expect(
            submission.label.hasSuffix("due \(RelativeDate.absolute(submission.day.date, relativeTo: today.date))"))
        #expect(submission.label.hasPrefix("1 submission") || submission.label.hasPrefix("2 submissions"))

        // A session that does name one module takes that module's colour.
        let single = ProgrammeEvent(
            startDate: RealCalendar.day(2026, 10, 5).date, endDate: RealCalendar.day(2026, 10, 5).date,
            kind: .online, title: "Programming", moduleCodes: ["COM1018DA"], sourceUID: "single",
            lastImportedAt: RealCalendar.importedAt)
        let withSingle = try #require(
            TermStrip(
                calendar: calendar, events: events + [single], submissionDates: submissions, today: today,
                moduleColours: ["COM1018DA": .teal]))
        let coloured = withSingle.marks.filter { $0.moduleColour == .teal }
        #expect(coloured.map(\.label) == ["Programming, 5 Oct"])
    }

    @Test("mid-term the strip places today, says the week, and counts to the next submission")
    func midTerm() throws {
        let strip = try strip(on: RealCalendar.day(2026, 10, 13))
        #expect(strip.caption == "week 4 of 13")
        let today = try #require(strip.todayPosition)
        #expect(today > 0.2 && today < 0.3)
        #expect(strip.daysToNextSubmission == 2)
        #expect(strip.summary == "Term 1, week 4 of 13. Next submission in 2 days.")
        let sessions = strip.marks.filter { $0.kind == .session }
        #expect(!sessions.isEmpty)
        #expect(sessions.allSatisfy { $0.day.isoWeekday == 1 }, "online sessions are Mondays")
        #expect(strip.marks == strip.marks.sorted { ($0.start, $0.day) < ($1.start, $1.day) })
        #expect(strip.marks.allSatisfy { $0.start >= 0 && $0.end <= 1 && $0.start <= $0.end })
    }

    @Test("after the last submission of a term the summary says so")
    func afterLastSubmission() throws {
        let strip = try strip(on: RealCalendar.day(2026, 12, 18))
        #expect(strip.daysToNextSubmission == nil || strip.term.number != 1)
        if strip.term.number == 1 {
            #expect(strip.summary.hasSuffix("No submissions left this term."))
        }
    }
}
