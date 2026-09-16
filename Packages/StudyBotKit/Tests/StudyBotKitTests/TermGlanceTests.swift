import Foundation
import StudyBotCore
import StudyBotKit
import Testing

@Suite("TermGlance — four true numbers")
struct TermGlanceTests {
    private static let t0 = SyncClient.t0

    private func glance(
        on day: LocalDay, sessions: [Session] = [], evidence: [Evidence] = [], hours: [OTJEntry] = []
    ) throws -> TermGlance {
        let events = try RealCalendar.events()
        let calendar = TermCalendar(events: events, derivedAt: RealCalendar.importedAt)
        let term = try #require(calendar.term(containing: day) ?? calendar.nextTerm(after: day))
        return TermGlance(
            term: term, today: day, weekOfTerm: calendar.weekOfTerm(day), slots: SessionCatalog.slots(in: events),
            sessions: sessions, evidence: evidence, hours: hours, targetPerWeek: 6)
    }

    @Test("before induction everything is zero, including the target")
    func beforeTerm() throws {
        let glance = try glance(on: RealCalendar.day(2026, 9, 16))
        #expect(glance.sessionsHeld == 0 && glance.sessionsAttended == 0)
        #expect(glance.hoursTarget == 0)
        #expect(glance.lines.map(\.value) == ["0 of 0", "0", "0", "0 of 0"])
    }

    @Test("in week two: sessions held so far, attended by notes or by a logged hour, and the target so far")
    func weekTwo() throws {
        let events = try RealCalendar.events()
        let slots = SessionCatalog.slots(in: events)
        let today = RealCalendar.day(2026, 9, 29)
        let held = slots.filter { $0.day <= today && $0.day >= RealCalendar.day(2026, 9, 22) }
        let monday = try #require(slots.first { $0.day == RealCalendar.day(2026, 9, 28) })
        let blockDay = try #require(slots.first { $0.day == RealCalendar.day(2026, 9, 23) })
        let noted = Session(sync: .new(id: monday.id, at: Self.t0), title: monday.title, date: monday.day.date, liveNotes: "- sets")
        let attendedByHours = OTJEntry(
            sync: .new(at: Self.t0), date: blockDay.day.date, hours: 7, category: .workshop, description: "Block 1",
            sessionID: blockDay.id)
        let evidence = Evidence(
            sync: .new(at: Self.t0), title: "Sprint", date: RealCalendar.day(2026, 9, 25).date, summary: "s",
            source: .workProject)
        let old = Evidence(
            sync: .new(at: Self.t0), title: "Old", date: RealCalendar.day(2026, 9, 1).date, summary: "s",
            source: .workProject)
        let glance = try glance(on: today, sessions: [noted], evidence: [evidence, old], hours: [attendedByHours])
        #expect(glance.sessionsHeld == held.count && held.count >= 4)
        #expect(glance.sessionsAttended == 2)
        #expect(glance.notesWritten == 1)
        #expect(glance.evidenceLogged == 1, "September 1st is before the term")
        #expect(glance.hoursLogged == 7)
        #expect(glance.hoursTarget == 12, "two weeks of term at 6 hours")
        #expect(glance.lines.last?.value == "7 of 12")
        #expect(TermGlance.hours(4.5) == "4.5" && TermGlance.hours(6) == "6")
    }
}
