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
