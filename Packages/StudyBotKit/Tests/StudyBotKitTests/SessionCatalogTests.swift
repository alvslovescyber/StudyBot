import Foundation
import StudyBotCore
import StudyBotKit
import Testing

@Suite("SessionCatalog — sessions from the real calendar")
struct SessionCatalogTests {
    @Test("Block 1 is three days: induction, then two on-campus days, with stable ids")
    func blockOne() throws {
        let events = try RealCalendar.events()
        let calendar = TermCalendar(events: events, derivedAt: RealCalendar.importedAt)
        let block = try #require(calendar.blocks.first)
        let days = SessionCatalog.days(of: block, in: events)
        #expect(
            days.map(\.day) == [
                RealCalendar.day(2026, 9, 22), RealCalendar.day(2026, 9, 23), RealCalendar.day(2026, 9, 24),
            ])
        #expect(days[0].slots.map(\.title) == ["Induction"])
        #expect(days[1].slots.map(\.title) == ["On campus, day 1"])
        #expect(days[2].slots.map(\.title) == ["On campus, day 2"])
        #expect(days[1].slots.first?.eventID == days[2].slots.first?.eventID, "one event, two sessions")
        #expect(days[1].slots.first?.id != days[2].slots.first?.id)
        let again = SessionCatalog.days(of: block, in: events)
        #expect(again == days, "ids are stable across Macs")
        #expect(
            days[0].slots.first?.id
                == Session.stableID(eventSourceUID: days[0].slots[0].eventSourceUID, dayISO: "2026-09-22"))
    }

    @Test("Mondays are single online slots and modules filter them")
    func mondays() throws {
        let events = try RealCalendar.events()
        let monday = try #require(SessionCatalog.slot(on: RealCalendar.day(2026, 9, 28), in: events))
        #expect(monday.kind == .online)
        #expect(monday.title == "Online lectures")
        #expect(monday.moduleCodes.contains("COM1018DA"))
        #expect(SessionCatalog.slot(on: RealCalendar.day(2026, 9, 29), in: events) == nil)
        let programming = SessionCatalog.slots(in: events, moduleCode: "COM1018DA")
        #expect(!programming.isEmpty)
        #expect(programming.allSatisfy { $0.moduleCodes.contains("COM1018DA") })
        #expect(programming == programming.sorted { ($0.day, $0.title) < ($1.day, $1.title) })
        let created = monday.newSession(moduleID: nil, at: RealCalendar.importedAt, deviceID: "air")
        #expect(created.id == monday.id && created.programmeEventID == monday.eventID)
        #expect(LocalDay(created.date) == monday.day)
    }
}
