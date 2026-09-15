import Foundation
import StudyBotCore
import StudyBotKit
import Testing

/// The importer against a real store: first launch, re-import, a reissued calendar.
@Suite("ProgrammeCalendarService — §4A import behaviour against a store")
struct ProgrammeCalendarServiceTests {
    private let now = RealCalendar.importedAt
    private var later: Date { now.addingTimeInterval(30 * 86_400) }

    /// The bundled ICS with one submission moved from 15 to 22 October 2026.
    private func movedDeadlineICS() throws -> Data {
        let text = try #require(String(data: try BundledProgrammeCalendar.data(), encoding: .utf8))
        let moved = text.replacingOccurrences(
            of: "DTSTART;VALUE=DATE:20261015\r\nDTEND;VALUE=DATE:20261016",
            with: "DTSTART;VALUE=DATE:20261022\r\nDTEND;VALUE=DATE:20261023")
        #expect(moved != text)
        return Data(moved.utf8)
    }

    /// The bundled ICS without the 28 September 2026 online lecture.
    private func removedSessionICS() throws -> Data {
        let text = try #require(String(data: try BundledProgrammeCalendar.data(), encoding: .utf8))
        let marker = "UID:dtsl6-2026-online-lectures-2026-09-28@programme.calendar"
        let uidRange = try #require(text.range(of: marker))
        let begin = try #require(
            text.range(of: "BEGIN:VEVENT", options: .backwards, range: text.startIndex..<uidRange.lowerBound))
        let endMarker = "END:VEVENT\r\n"
        let end = try #require(text.range(of: endMarker, range: uidRange.upperBound..<text.endIndex))
        var trimmed = text
        trimmed.removeSubrange(begin.lowerBound..<end.upperBound)
        return Data(trimmed.utf8)
    }

    private func assertFirstRun(_ summary: ProgrammeCalendarService.Summary, store: any ProgrammeStore)
        async throws
    {
        #expect(summary.issues.isEmpty)
        #expect(summary.eventsAdded == 156)
        #expect(summary.termsAdded == 9)
        #expect(summary.modulesAdded == 26)
        #expect(summary.assignmentsAdded == 30)
        #expect(summary.assignmentsRescheduled == 0)
        #expect(try await store.programmeEvents(includeCancelled: true).count == 156)
        #expect(try await store.fetchAll(Term.self, includeDeleted: false).count == 9)
        #expect(try await store.fetchAll(Module.self, includeDeleted: false).count == 26)
        let assignments = try await store.fetchAll(Assignment.self, includeDeleted: false).map(\.value)
        #expect(assignments.count == 30)
        #expect(assignments.allSatisfy { $0.status == .backlog && $0.moduleID == nil && $0.dueDate != nil })
        #expect(assignments.contains { $0.title == "Submission due 15 October 2026" })
    }

    @Test("first launch against the in-memory store: 156 events, 9 terms, 26 modules, 30 stubs")
    func firstRunInMemory() async throws {
        let store = InMemoryProgrammeStore()
        let summary = try await ProgrammeCalendarService(store: store).importBundledCalendar(now: now)
        try await assertFirstRun(summary, store: store)
    }

    @Test("first launch against a real on-disk store, then a second run that changes nothing")
    func firstRunOnDiskThenIdempotent() async throws {
        let temp = try TemporaryStore()
        defer { temp.remove() }
        let db = try Database.onDisk(at: temp.url)
        let service = ProgrammeCalendarService(store: db)

        let first = try await service.importBundledCalendar(now: now)
        try await assertFirstRun(first, store: db)
        let idsBefore = Set(try await db.fetchAll(Assignment.self).map(\.id))

        let second = try await service.importBundledCalendar(now: later)
        #expect(!second.changedAnything, "\(second)")
        #expect(try await db.programmeEvents().count == 156)
        #expect(try await db.count(Term.self) == 9)
        #expect(try await db.count(Module.self) == 26)
        #expect(try await db.count(Assignment.self) == 30)
        #expect(Set(try await db.fetchAll(Assignment.self).map(\.id)) == idsBefore)

        // Everything is still there after reopening the file.
        let reopened = try Database.onDisk(at: temp.url)
        #expect(try await reopened.count(Assignment.self) == 30)
        #expect(try await reopened.programmeEvents(includeCancelled: false).count == 156)
    }

    @Test("a moved deadline reschedules the stub, unless the user has edited the date by hand")
    func movedDeadline() async throws {
        let store = InMemoryProgrammeStore()
        let service = ProgrammeCalendarService(store: store)
        _ = try await service.importBundledCalendar(now: now)

        // The user hand-edits a different stub's date so it must not be touched.
        let decemberUID = "dtsl6-2026-assignment-2026-12-03@programme.calendar"
        let decemberEventID = ProgrammeEvent.stableID(forSourceUID: decemberUID)
        var december = try #require(
            try await store.fetchAll(Assignment.self, includeDeleted: false).first {
                $0.value.programmeEventID == decemberEventID
            }
        ).value
        december.dueDate = LocalDay(year: 2026, month: 12, day: 10).date
        december.fieldOverrides.insert("dueDate")
        await store.saveAll([december])

        let summary = try await service.importCalendar(try movedDeadlineICS(), now: later)
        #expect(summary.eventsUpdated == 1)
        #expect(summary.assignmentsRescheduled == 1)
        #expect(summary.assignmentsAdded == 0)
        #expect(summary.eventsAdded == 0)

        let octoberEventID = ProgrammeEvent.stableID(
            forSourceUID: "dtsl6-2026-assignment-2026-10-15@programme.calendar")
        let assignments = try await store.fetchAll(Assignment.self, includeDeleted: false).map(\.value)
        let october = try #require(assignments.first { $0.programmeEventID == octoberEventID })
        #expect(october.dueDate.map(LocalDay.init) == LocalDay(year: 2026, month: 10, day: 22))
        #expect(october.sync.updatedAt == later)
        let untouched = try #require(assignments.first { $0.programmeEventID == decemberEventID })
        #expect(untouched.dueDate.map(LocalDay.init) == LocalDay(year: 2026, month: 12, day: 10))
        #expect(assignments.count == 30)
    }

    @Test("a removed session is cancelled, and a note attached to it still resolves")
    func removedSession() async throws {
        let store = InMemoryProgrammeStore()
        let service = ProgrammeCalendarService(store: store)
        _ = try await service.importBundledCalendar(now: now)

        let uid = "dtsl6-2026-online-lectures-2026-09-28@programme.calendar"
        let eventID = ProgrammeEvent.stableID(forSourceUID: uid)
        let note = Session(
            sync: .new(at: now), title: "Programming week 1", programmeEventID: eventID, date: now,
            liveNotes: "- first lecture")
        await store.saveAll([note])

        let summary = try await service.importCalendar(try removedSessionICS(), now: later)
        #expect(summary.eventsCancelled == 1)
        #expect(summary.assignmentsAdded == 0)
        #expect(summary.modulesAdded == 0)
        let events = try await store.programmeEvents(includeCancelled: true)
        #expect(events.count == 156)
        let cancelled = try #require(events.first { $0.sourceUID == uid })
        #expect(cancelled.isCancelled)
        #expect(cancelled.id == eventID)
        let session = try #require(try await store.fetchAll(Session.self, includeDeleted: false).first)
        #expect(session.value.programmeEventID == cancelled.id)
        #expect(try await store.fetchAll(Term.self, includeDeleted: false).count == 9)
    }

    @Test("a user's module edits survive a re-import")
    func moduleEditsSurvive() async throws {
        let store = InMemoryProgrammeStore()
        let service = ProgrammeCalendarService(store: store)
        _ = try await service.importBundledCalendar(now: now)
        var programming = try #require(
            try await store.fetchAll(Module.self, includeDeleted: false).first {
                $0.value.code == "COM1018DA"
            }
        ).value
        programming.name = "Prog"
        programming.colour = .teal
        await store.saveAll([programming])
        _ = try await service.importBundledCalendar(now: later)
        let after = try #require(
            try await store.fetchAll(Module.self, includeDeleted: false).first {
                $0.value.code == "COM1018DA"
            }
        ).value
        #expect(after.name == "Prog")
        #expect(after.colour == .teal)
    }
}
