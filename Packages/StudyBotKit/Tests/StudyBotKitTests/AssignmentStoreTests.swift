import Foundation
import StudyBotCore
import StudyBotKit
import Testing

/// The store the Assignments screen sits on, judged against the real import on the real
/// first day: 14 September 2026, 30 date-titled stubs, no modules on any of them.
@MainActor
@Suite("AssignmentStore — §6.2 scope, grouping and explicit save")
struct AssignmentStoreTests {
    /// Monday 14 September 2026, 10:00 London.
    private nonisolated static let day1 = LocalDay(year: 2026, month: 9, day: 14).date.addingTimeInterval(
        10 * 3_600)

    private func makeStore(now: Date = day1) async throws -> AssignmentStore {
        let records = InMemoryRecordStore()
        _ = try await ProgrammeCalendarService(store: records).importBundledCalendar(now: now)
        let store = AssignmentStore(store: records, deviceID: "mac-a", now: { now })
        await store.load()
        return store
    }

    @Test("a hover action sets one field, marks it hand-set, and the row moves group")
    func quickSet() async throws {
        let store = try await makeStore()
        let stub = try #require(store.visible.first)
        #expect(store.groups.map(\.status) == [.backlog])

        await store.set(stub.id, status: .drafting)
        let drafting = try #require(store.assignment(id: stub.id))
        #expect(drafting.status == .drafting)
        #expect(drafting.fieldOverrides == ["status"])
        #expect(drafting.sync.dirty)
        #expect(store.groups.map(\.status) == [.drafting, .backlog], "work in progress leads the list")
        #expect(store.groups.first?.assignments.map(\.id) == [stub.id])

        await store.set(stub.id, priority: .high)
        #expect(store.assignment(id: stub.id)?.priority == .high)
        #expect(store.assignment(id: stub.id)?.fieldOverrides == ["status", "priority"])

        let newDue = LocalDay(year: 2026, month: 10, day: 22).date.addingTimeInterval(13 * 3_600)
        await store.set(stub.id, dueDate: newDue)
        let moved = try #require(store.assignment(id: stub.id))
        #expect(moved.dueDate == LocalDay(year: 2026, month: 10, day: 22).date, "stored as a day")
        #expect(moved.termID == store.currentTerm?.id, "the term follows the date")
        #expect(moved.fieldOverrides == ["status", "priority", "dueDate"])

        let version = moved.sync.updatedAt
        await store.set(stub.id, status: .drafting)
        #expect(
            store.assignment(id: stub.id)?.sync.updatedAt == version, "setting the same value writes nothing")
    }

    @Test("on 14 September 2026 the default scope shows the three term-1 stubs and hides 27")
    func firstDayScope() async throws {
        let store = try await makeStore()
        #expect(store.scope == .currentTerm)
        #expect(store.currentTerm?.shortLabel == "Y1 T1", "before induction, 'current' is the coming term")
        #expect(store.visible.count == 3)
        #expect(store.hiddenCount == 27)
        #expect(store.hiddenAreAllLater)
        #expect(
            store.visible.map(\.title) == [
                "Submission due 15 October 2026", "Submission due 3 December 2026",
                "Submission due 17 December 2026",
            ])
        #expect(store.visible.allSatisfy { $0.moduleID == nil && $0.isCalendarStub })
        #expect(store.groups.map(\.status) == [.backlog])
        #expect(store.groups.first?.assignments.count == 3)
    }

    @Test("current year shows ten, all shows thirty")
    func widerScopes() async throws {
        let store = try await makeStore()
        store.scope = .currentYear
        #expect(store.visible.count == 10)
        #expect(store.hiddenCount == 20)
        store.scope = .all
        #expect(store.visible.count == 30)
        #expect(store.hiddenCount == 0)
        #expect(store.visible.first?.title == "Submission due 15 October 2026", "sorted by due date")
    }

    @Test("in a gap between terms the next term is current; inside a term that term is")
    func currentTermAcrossGaps() async throws {
        let summer = try await makeStore(now: LocalDay(year: 2027, month: 8, day: 20).date)
        #expect(summer.currentTerm?.shortLabel == "Y2 T1")
        let november = try await makeStore(now: LocalDay(year: 2026, month: 11, day: 5).date)
        #expect(november.currentTerm?.shortLabel == "Y1 T1")
        #expect(november.visible.count == 3)
    }

    @Test("saving records the edited fields as overrides, marks dirty, and re-derives the term")
    func explicitSave() async throws {
        let store = try await makeStore()
        var stub = try #require(store.visible.first)
        #expect(stub.fieldOverrides.isEmpty)
        let programming = try #require(store.modules.first { $0.code == "COM1018DA" })

        stub.title = "Programming coursework 1"
        stub.moduleID = programming.id
        stub.status = .drafting
        stub.dueDate = LocalDay(year: 2027, month: 1, day: 20).date  // moved into term 2
        await store.save(stub, changedFields: ["title", "moduleID", "status", "dueDate"])

        #expect(store.lastError == nil)
        let saved = try #require(store.assignment(id: stub.id))
        #expect(saved.title == "Programming coursework 1")
        #expect(saved.fieldOverrides == ["title", "moduleID", "status", "dueDate"])
        #expect(saved.sync.dirty)
        #expect(saved.sync.deviceID == "mac-a")
        #expect(saved.sync.updatedAt == Self.day1)
        #expect(saved.termID == Term.stableID(year: 1, number: 2))
        #expect(!saved.isCalendarStub)
        #expect(store.visible.count == 2, "it moved out of the current term")
        #expect(store.module(for: saved)?.shortCode == "PROG")
    }

    @Test("a save with a blank title is refused with a legible message and nothing is written")
    func invalidSaveRefused() async throws {
        let store = try await makeStore()
        var stub = try #require(store.visible.first)
        stub.title = "   "
        await store.save(stub, changedFields: ["title"])
        #expect(store.lastError == "Can't be empty")
        #expect(store.assignment(id: stub.id)?.title == "Submission due 15 October 2026")
    }

    @Test("a new assignment has no due date and is visible in every scope")
    func createAssignment() async throws {
        let store = try await makeStore()
        let created = try #require(await store.createAssignment())
        #expect(created.status == .backlog)
        #expect(created.dueDate == nil)
        #expect(store.visible.contains { $0.id == created.id })
        store.scope = .all
        #expect(store.visible.count == 31)
        #expect(store.groups.map(\.status) == [.backlog])
    }

    @Test("the module filter narrows the list and the scope choice persists to Settings")
    func moduleFilterAndPersistence() async throws {
        let records = InMemoryRecordStore()
        _ = try await ProgrammeCalendarService(store: records).importBundledCalendar(now: Self.day1)
        let store = AssignmentStore(store: records, deviceID: "mac-a", now: { Self.day1 })
        await store.load()
        store.moduleFilter = Module.stableID(forCode: "COM1018DA")
        #expect(store.visible.isEmpty, "no stub has a module yet")
        store.moduleFilter = nil
        store.scope = .all
        #expect(
            try await eventually {
                try await records.fetchAll(Settings.self, includeDeleted: false).first?.value
                    .assignmentListScope == .all
            }, "the scope choice persists")
        let persisted = try await records.fetchAll(Settings.self, includeDeleted: false).first?.value
        #expect(persisted?.sync.deviceID == "mac-a")
    }
}
