import Foundation
import StudyBotCore
import StudyBotKit
import Testing

@Suite("Database — the SwiftData store")
struct DatabaseTests {
    private func roundTrip<T: Persistable>(_ value: T, in db: Database) async throws {
        try await db.save(value)
        let fetched = try await db.fetch(T.self, id: value.id)
        #expect(fetched?.value == value, "\(T.recordType)")
        #expect(fetched?.unknownFields == [:], "\(T.recordType)")
        #expect(fetched?.value.sync == value.sync, "\(T.recordType) sync metadata must persist in full")
    }

    @Test("every persistable type round-trips through the store unchanged, sync metadata included")
    func allTypesRoundTrip() async throws {
        let db = try Database.inMemory()
        try await roundTrip(SampleRecords.module, in: db)
        try await roundTrip(SampleRecords.term, in: db)
        try await roundTrip(SampleRecords.assignment, in: db)
        try await roundTrip(SampleRecords.session, in: db)
        try await roundTrip(SampleRecords.deck, in: db)
        try await roundTrip(SampleRecords.card, in: db)
        try await roundTrip(SampleRecords.quizAttempt, in: db)
        try await roundTrip(SampleRecords.ksb, in: db)
        try await roundTrip(SampleRecords.evidence, in: db)
        try await roundTrip(SampleRecords.otjEntry, in: db)
        try await roundTrip(SampleRecords.proposal, in: db)
        try await roundTrip(SampleRecords.settings, in: db)
        try await roundTrip(SampleRecords.attachment, in: db)
        try await roundTrip(SampleRecords.aiRun, in: db)
    }

    @Test("seq and baseVersion survive even though nothing reads them yet")
    func syncFieldsPersistInFull() async throws {
        let db = try Database.inMemory()
        var assignment = SampleRecords.assignment
        assignment.sync.seq = 99_001
        assignment.sync.baseVersion = 7
        assignment.sync.version = 8
        assignment.sync.dirty = false
        try await db.save(assignment)
        let fetched = try #require(try await db.fetch(Assignment.self, id: assignment.id))
        #expect(fetched.value.sync.seq == 99_001)
        #expect(fetched.value.sync.baseVersion == 7)
        #expect(fetched.value.sync.version == 8)
        #expect(!fetched.value.sync.dirty)
        #expect(fetched.value.sync.updatedAt == assignment.sync.updatedAt, "sub-second precision kept")
    }

    @Test("saving twice updates in place: one row, latest content")
    func upsert() async throws {
        let db = try Database.inMemory()
        var assignment = SampleRecords.assignment
        try await db.save(assignment)
        assignment.title = "Renamed"
        assignment.status = .review
        try await db.save(assignment)
        #expect(try await db.count(Assignment.self) == 1)
        #expect(try await db.fetch(Assignment.self, id: assignment.id)?.value.title == "Renamed")
    }

    @Test("a tombstone hides the record from fetchAll and count but keeps the row and marks it dirty")
    func tombstones() async throws {
        let db = try Database.inMemory()
        var clean = SampleRecords.evidence
        clean.sync.dirty = false
        try await db.save(clean)
        try await db.save(SampleRecords.evidence)  // a second, different id
        #expect(try await db.count(Evidence.self) == 2)

        let deletedAt = SampleRecords.now.addingTimeInterval(3_600)
        try await db.tombstone(Evidence.self, id: clean.id, at: deletedAt)

        #expect(try await db.count(Evidence.self) == 1)
        #expect(try await db.count(Evidence.self, includeDeleted: true) == 2)
        #expect(try await db.fetchAll(Evidence.self).map(\.id) != [clean.id])
        let gone = try #require(try await db.fetch(Evidence.self, id: clean.id))
        #expect(gone.value.sync.deletedAt == deletedAt)
        #expect(gone.value.sync.dirty)
        #expect(try await db.fetchDirty(Evidence.self).map(\.id).contains(clean.id))

        try await db.purge(Evidence.self, id: clean.id)
        #expect(try await db.fetch(Evidence.self, id: clean.id) == nil)
        #expect(try await db.count(Evidence.self, includeDeleted: true) == 1)
    }

    @Test("fetchDirty returns only records the server has not acknowledged")
    func dirtyQuery() async throws {
        let db = try Database.inMemory()
        var acknowledged = SampleRecords.card
        acknowledged.sync.dirty = false
        let pending = SampleRecords.card
        try await db.saveAll([acknowledged, pending])
        let dirty = try await db.fetchDirty(Card.self)
        #expect(dirty.map(\.id) == [pending.id])
    }

    @Test("programme events are matched by sourceUID and can be filtered to live ones")
    func programmeEvents() async throws {
        let db = try Database.inMemory()
        var event = SampleRecords.programmeEvent
        try await db.saveProgrammeEvents([event])
        event.cancelledAt = SampleRecords.now
        try await db.saveProgrammeEvents([event])  // same UID: update, not a second row
        #expect(try await db.programmeEvents().count == 1)
        #expect(try await db.programmeEvents(includeCancelled: false).isEmpty)
        let stored = try #require(try await db.programmeEvent(sourceUID: "uid"))
        #expect(stored == event)
        #expect(try await db.programmeEvent(sourceUID: "nope") == nil)
    }

    @Test("note revisions keep the last 20 idle snapshots per session and prune old conflict losers")
    func noteRevisions() async throws {
        let db = try Database.inMemory()
        let sessionID = SampleRecords.sessionID
        for index in 0..<25 {
            try await db.addNoteRevision(
                NoteRevision(
                    sessionID: sessionID, body: "v\(index)",
                    capturedAt: SampleRecords.now.addingTimeInterval(Double(index) * 30),
                    reason: .idleSnapshot))
        }
        try await db.addNoteRevision(
            NoteRevision(
                sessionID: sessionID, body: "loser", capturedAt: SampleRecords.now, reason: .conflictLoser))
        try await db.addNoteRevision(
            NoteRevision(
                sessionID: UUID(), body: "other session", capturedAt: SampleRecords.now, reason: .idleSnapshot
            ))

        let revisions = try await db.noteRevisions(for: sessionID)
        #expect(revisions.count == 21)
        #expect(revisions.filter { $0.reason == .idleSnapshot }.count == 20)
        #expect(revisions.first?.body == "v24", "newest first")
        #expect(!revisions.contains { $0.body == "v0" }, "the oldest snapshots were trimmed")

        try await db.pruneConflictLosers(now: SampleRecords.now.addingTimeInterval(31 * 86_400))
        #expect(try await db.noteRevisions(for: sessionID).count == 20)
    }

    @Test("an on-disk store survives being closed and reopened")
    func onDiskPersistence() async throws {
        let temp = try TemporaryStore()
        defer { temp.remove() }
        let assignment = SampleRecords.assignment
        do {
            let db = try Database.onDisk(at: temp.url)
            try await db.save(assignment)
            try await db.saveProgrammeEvents([SampleRecords.programmeEvent])
        }
        let reopened = try Database.onDisk(at: temp.url)
        #expect(try await reopened.fetch(Assignment.self, id: assignment.id)?.value == assignment)
        #expect(try await reopened.programmeEvents().count == 1)
    }
}
