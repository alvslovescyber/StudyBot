import Foundation
import StudyBotCore
import StudyBotKit
import Testing

/// Revisions and losers in memory, for the store's tests.
actor FakeRevisionStore: NoteRevisionStore {
    var revisions: [NoteRevision] = []
    var losers: [ConflictLoser] = []

    func addNoteRevision(_ revision: NoteRevision) async throws { revisions.append(revision) }
    func noteRevisions(for sessionID: UUID) async throws -> [NoteRevision] {
        revisions.filter { $0.sessionID == sessionID }
    }
    func conflictLosers(for recordID: UUID) async throws -> [ConflictLoser] {
        losers.filter { $0.record.id == recordID }
    }
    func add(loser: ConflictLoser) { losers.append(loser) }
}

@MainActor
@Suite("NotesStore — live notes, questions, snapshots")
struct NotesStoreTests {
    private nonisolated static let t0 = SyncClient.t0

    private struct Harness {
        let store: NotesStore
        let records: InMemoryRecordStore
        let revisions: FakeRevisionStore
        let slot: SessionSlot
    }

    private func makeStore() throws -> Harness {
        let records = InMemoryRecordStore()
        let revisions = FakeRevisionStore()
        let store = NotesStore(
            store: records, revisions: revisions, deviceID: "air", now: { Self.t0 },
            saveDelay: .milliseconds(40), snapshotDelay: .milliseconds(400))
        let events = try RealCalendar.events()
        let slot = try #require(SessionCatalog.slot(on: RealCalendar.day(2026, 9, 28), in: events))
        return Harness(store: store, records: records, revisions: revisions, slot: slot)
    }

    @Test("opening a slot creates one session with the stable id and persists it")
    func openCreates() async throws {
        let harness = try makeStore()
        let (store, records, slot) = (harness.store, harness.records, harness.slot)
        let session = await store.open(slot, moduleID: nil)
        #expect(session.id == slot.id)
        #expect(try await records.fetch(Session.self, id: slot.id)?.value == session)
        let again = await store.open(slot, moduleID: nil)
        #expect(again == session, "a second open returns the same record")
        #expect(try await records.fetchAll(Session.self, includeDeleted: false).count == 1)
    }

    @Test("typing updates questions at once, writes after a pause, and snapshots after quiet")
    func typing() async throws {
        let harness = try makeStore()
        let (store, records, revisions, slot) = (
            harness.store, harness.records, harness.revisions, harness.slot
        )
        var writes = 0
        store.didWrite = { writes += 1 }
        let session = await store.open(slot, moduleID: nil)
        let writesAfterOpen = writes

        store.updateLiveNotes(session.id, text: "- sets\nASK: does order matter")
        store.updateLiveNotes(session.id, text: "- sets\nASK: does order matter\n- relations")
        #expect(store.session(id: session.id)?.openQuestions == ["does order matter"])
        #expect(store.session(id: session.id)?.sync.dirty == true)
        #expect(try await records.fetch(Session.self, id: slot.id)?.value.liveNotes == "", "not written yet")

        #expect(
            try await eventually {
                try await records.fetch(Session.self, id: slot.id)?.value.liveNotes.hasSuffix("- relations")
                    == true
            }, "written once typing paused")
        #expect(writes == writesAfterOpen + 1, "one write for two keystrokes")
        #expect(await revisions.revisions.isEmpty, "no snapshot yet")

        #expect(await eventually { await revisions.revisions.count == 1 }, "a snapshot after quiet")
        let snapshots = await revisions.revisions
        #expect(snapshots.count == 1)
        #expect(snapshots.first?.reason == .idleSnapshot)
        #expect(snapshots.first?.body.hasSuffix("- relations") == true)

        // Quiet again with nothing changed, well past the snapshot delay: no second identical snapshot.
        try await Task.sleep(for: .milliseconds(500))
        #expect(await revisions.revisions.count == 1)
    }

    @Test("the capture bar appends a note or a question, and questions aggregate across sessions")
    func appendAndAggregate() async throws {
        let harness = try makeStore()
        let (store, monday) = (harness.store, harness.slot)
        let events = try RealCalendar.events()
        let calendar = TermCalendar(events: events, derivedAt: RealCalendar.importedAt)
        let block = try #require(calendar.blocks.first)
        let days = SessionCatalog.days(of: block, in: events)
        let induction = await store.open(days[0].slots[0], moduleID: nil)
        let dayTwo = await store.open(days[1].slots[0], moduleID: nil)
        _ = await store.open(monday, moduleID: nil)

        store.append("bring laptop charger", asQuestion: false, to: induction.id)
        store.append("is the exam open book", asQuestion: true, to: induction.id)
        store.append("ASK: where is the lab", asQuestion: true, to: dayTwo.id)
        #expect(
            store.session(id: induction.id)?.liveNotes == "bring laptop charger\nASK: is the exam open book\n"
        )

        let questions = store.questions(in: [dayTwo.id, induction.id, monday.id])
        #expect(
            questions.map(\.text) == ["is the exam open book", "where is the lab"], "date order, all days")
        #expect(questions.first?.sessionTitle == "Induction")
        await store.flushAll()
    }

    @Test("Today reads every question, the recent sessions with notes, and a note's first line")
    func todayAccessors() async throws {
        let harness = try makeStore()
        let (store, slot) = (harness.store, harness.slot)
        let events = try RealCalendar.events()
        let other = try #require(SessionCatalog.slot(on: RealCalendar.day(2026, 10, 5), in: events))
        let first = await store.open(slot, moduleID: nil)
        let second = await store.open(other, moduleID: nil)
        store.updateLiveNotes(first.id, text: "- sets\nASK: does order matter\n")
        store.updateLiveNotes(second.id, text: "ASK: is the exam open book\n- relations\n")
        _ = await store.open(
            try #require(SessionCatalog.slot(on: RealCalendar.day(2026, 10, 12), in: events)), moduleID: nil)

        #expect(store.allSessions.count == 3)
        #expect(store.allQuestions.map(\.text) == ["does order matter", "is the exam open book"])
        #expect(
            store.recentSessions(limit: 5).map(\.id) == [second.id, first.id], "newest first, notes only")
        #expect(store.recentSessions(limit: 1).count == 1)
        #expect(store.session(id: first.id)?.firstNoteLine == "sets")
        #expect(store.session(id: second.id)?.firstNoteLine == "ASK: is the exam open book")
        #expect(
            Session(sync: .new(at: Self.t0), title: "t", date: Self.t0, liveNotes: "\n  \n").firstNoteLine
                == nil)
        await store.flushAll()
    }

    @Test("restoring an older body keeps the current one first, and losers are surfaced")
    func restoreAndLosers() async throws {
        let harness = try makeStore()
        let (store, revisions, slot) = (harness.store, harness.revisions, harness.slot)
        let session = await store.open(slot, moduleID: nil)
        store.updateLiveNotes(session.id, text: "current notes")
        await store.flush(session.id)
        let loser = ConflictLoser(
            record: SyncRecord(
                type: "session", id: session.id, baseVersion: 1, updatedAt: Self.t0,
                fields: ["liveNotes": "the other Mac's notes"]),
            archivedAt: Self.t0, replacedByVersion: 2, serverArchiveID: "c_1")
        await revisions.add(loser: loser)
        #expect(await store.conflictLosers(for: session.id).count == 1)

        await store.restore(body: "the other Mac's notes", into: session.id)
        #expect(store.session(id: session.id)?.liveNotes == "the other Mac's notes")
        let kept = await revisions.revisions
        #expect(
            kept.contains { $0.body == "current notes" && $0.reason == .preSync }, "restoring is reversible")
    }
}
