import Foundation
import StudyBotCore
import StudyBotKit
import Testing

@Suite("AssignmentStubs — §4A the 30 backlog assignments")
struct AssignmentStubsTests {
    private func stubs() throws -> [Assignment] {
        let reading = try ICSProgrammeCalendarReader.read(
            try BundledProgrammeCalendar.data(), importedAt: RealCalendar.importedAt)
        let terms = TermCalendar(events: reading.events, derivedAt: RealCalendar.importedAt)
        let modules = ModuleSeeder.modules(from: reading, terms: terms, now: RealCalendar.importedAt)
        return AssignmentStubs.stubs(for: reading.events, modules: modules, now: RealCalendar.importedAt)
    }

    @Test("30 stubs, one per submission, in backlog with the due date set and the event linked")
    func thirtyStubs() throws {
        let stubs = try stubs()
        #expect(stubs.count == 30)
        #expect(stubs.allSatisfy { $0.status == .backlog })
        #expect(stubs.allSatisfy { $0.dueDate != nil })
        #expect(stubs.allSatisfy { $0.programmeEventID != nil })
        #expect(stubs.allSatisfy { $0.isCalendarStub })
        #expect(stubs.allSatisfy { $0.isValid })
        #expect(Set(stubs.map(\.id)).count == 30)
        let dueDates = stubs.compactMap { $0.dueDate.map(LocalDay.init) }
        #expect(dueDates == dueDates.sorted())
        #expect(dueDates.first == LocalDay(year: 2026, month: 10, day: 15))
        #expect(dueDates.last == LocalDay(year: 2029, month: 6, day: 28))
    }

    @Test("the title is the date because the calendar names a whole term's modules, not one")
    func titles() throws {
        let stubs = try stubs()
        #expect(stubs.first?.title == "Submission due 15 October 2026")
        #expect(stubs.allSatisfy { $0.moduleID == nil })
    }

    @Test("ids are derived from the event UID, so a second derivation yields the same records")
    func deterministic() throws {
        let first = try stubs()
        let second = try stubs()
        #expect(first.map(\.id) == second.map(\.id))
        let events = try RealCalendar.events()
        let firstDeadline = try #require(events.first { $0.kind == .assignment })
        #expect(first.first?.id == AssignmentStubs.stableID(forEvent: firstDeadline))
        #expect(first.first?.programmeEventID == firstDeadline.id)
    }

    @Test("a single-module submission takes the module's name and id")
    func singleModule() throws {
        let now = RealCalendar.importedAt
        let module = Module(
            sync: .new(id: Module.stableID(forCode: "COM1018DA"), at: now), name: "Programming",
            code: "COM1018DA", colour: .indigo, year: 1, termNumber: 1)
        let event = ProgrammeEvent(
            startDate: LocalDay(year: 2026, month: 10, day: 15).date,
            endDate: LocalDay(year: 2026, month: 10, day: 15).date,
            kind: .assignment, title: "Assignment submission", moduleCodes: ["COM1018DA"],
            sourceUID: "single@programme.calendar", lastImportedAt: now)
        let cancelled = ProgrammeEvent(
            startDate: event.startDate, endDate: event.endDate, kind: .assignment, title: "Gone",
            moduleCodes: [], sourceUID: "gone@programme.calendar", cancelledAt: now, lastImportedAt: now)
        let stubs = AssignmentStubs.stubs(for: [event, cancelled], modules: [module], now: now)
        #expect(stubs.count == 1, "cancelled submissions produce no stub")
        #expect(stubs.first?.title == "Programming")
        #expect(stubs.first?.moduleID == module.id)
    }
}
