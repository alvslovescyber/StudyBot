import Foundation
import StudyBotCore
import StudyBotKit
import Testing

/// §3.10a: "unknown fields are round-tripped, not discarded." The loss scenario is a record
/// written by an updated Mac, read by a stale one, edited there and written back. The Codable
/// seam alone does not prove this; the path goes through the store.
@Suite("Unknown-field preservation through the store — §3.10a, §3.12 schema-version guard")
struct UnknownFieldPreservationTests {
    /// Fields as a newer build would send them: everything this build knows plus two it doesn't.
    private func fieldsFromNewerBuild() throws -> (fields: [String: JSONValue], sync: SyncMetadata) {
        let assignment = SampleRecords.assignment
        var fields = try RecordFields.fields(of: StoredRecord(assignment))
        fields["mentorName"] = "Dr Patel"
        fields["revisionPlan"] = ["stages": [1, 2, 3], "locked": false]
        fields["grade"] = .null  // a known optional, absent; must not be mistaken for unknown
        return (fields, assignment.sync)
    }

    @Test("the stale client keeps fields it does not understand and sends them back unchanged")
    func staleClientRoundTrip() async throws {
        let (fields, sync) = try fieldsFromNewerBuild()
        let db = try Database.inMemory()

        // 1. The stale build receives the record and stores it.
        let received = try RecordFields.record(Assignment.self, fields: fields, sync: sync)
        #expect(received.unknownFields.keys.sorted() == ["mentorName", "revisionPlan"])
        #expect(received.value.title == "Programming coursework 1")
        try await db.save(received)

        // 2. The user edits it on the stale build, through the plain save(value) path.
        var edited = try #require(try await db.fetch(Assignment.self, id: sync.id)).value
        edited.title = "Programming coursework 1 (final)"
        edited.status = .review
        edited.sync.markEdited(at: SampleRecords.now.addingTimeInterval(600))
        try await db.save(edited)

        // 3. What goes back on the wire still carries the newer build's fields.
        let stored = try #require(try await db.fetch(Assignment.self, id: sync.id))
        #expect(stored.value.title == "Programming coursework 1 (final)")
        #expect(stored.unknownFields["mentorName"] == "Dr Patel")
        #expect(stored.unknownFields["revisionPlan"] == ["stages": [1, 2, 3], "locked": false])
        let outgoing = try RecordFields.fields(of: stored)
        #expect(outgoing["mentorName"] == "Dr Patel")
        #expect(outgoing["revisionPlan"] == ["stages": [1, 2, 3], "locked": false])
        #expect(outgoing["title"] == "Programming coursework 1 (final)")
        #expect(outgoing["status"] == "review")
    }

    @Test("unknown fields survive the store being closed and reopened from disk")
    func survivesReopen() async throws {
        let temp = try TemporaryStore()
        defer { temp.remove() }
        let (fields, sync) = try fieldsFromNewerBuild()
        do {
            let db = try Database.onDisk(at: temp.url)
            try await db.save(try RecordFields.record(Assignment.self, fields: fields, sync: sync))
        }
        do {
            let db = try Database.onDisk(at: temp.url)
            var edited = try #require(try await db.fetch(Assignment.self, id: sync.id)).value
            edited.priority = .urgent
            try await db.save(edited)
        }
        let db = try Database.onDisk(at: temp.url)
        let stored = try #require(try await db.fetch(Assignment.self, id: sync.id))
        #expect(stored.value.priority == .urgent)
        #expect(stored.unknownFields["mentorName"] == "Dr Patel")
        #expect(stored.unknownFields["revisionPlan"] == ["stages": [1, 2, 3], "locked": false])
    }

    @Test("saveAll, the importer's path, also keeps unknown fields")
    func saveAllKeepsUnknownFields() async throws {
        let (fields, sync) = try fieldsFromNewerBuild()
        let db = try Database.inMemory()
        try await db.save(try RecordFields.record(Assignment.self, fields: fields, sync: sync))
        var value = try #require(try await db.fetch(Assignment.self, id: sync.id)).value
        value.dueDate = LocalDay(year: 2026, month: 10, day: 22).date
        try await db.saveAll([value])
        #expect(try await db.fetch(Assignment.self, id: sync.id)?.unknownFields["mentorName"] == "Dr Patel")
    }

    @Test("saving a StoredRecord replaces unknown fields deliberately; an empty map clears them")
    func explicitReplace() async throws {
        let (fields, sync) = try fieldsFromNewerBuild()
        let db = try Database.inMemory()
        let received = try RecordFields.record(Assignment.self, fields: fields, sync: sync)
        try await db.save(received)
        try await db.save(StoredRecord(received.value, unknownFields: ["onlyThis": 1]))
        #expect(try await db.fetch(Assignment.self, id: sync.id)?.unknownFields == ["onlyThis": 1])
        try await db.save(StoredRecord(received.value, unknownFields: [:]))
        #expect(try await db.fetch(Assignment.self, id: sync.id)?.unknownFields == [:])
    }

    @Test("a null for a known optional is not treated as an unknown field, and sync never leaks into fields")
    func nullsAndSync() throws {
        let (fields, sync) = try fieldsFromNewerBuild()
        let record = try RecordFields.record(Assignment.self, fields: fields, sync: sync)
        #expect(record.unknownFields["grade"] == nil)
        #expect(record.value.grade == nil)
        #expect(record.value.sync == sync)
        let outgoing = try RecordFields.fields(of: record)
        #expect(outgoing["sync"] == nil)
        #expect(outgoing["id"] == nil, "id travels at record level, not in fields")
    }

    @Test("the in-memory store keeps unknown fields the same way")
    func inMemoryStoreMatches() async throws {
        let (fields, sync) = try fieldsFromNewerBuild()
        let store = InMemoryProgrammeStore()
        await store.save(try RecordFields.record(Assignment.self, fields: fields, sync: sync))
        var value = try #require(await store.fetch(Assignment.self, id: sync.id)).value
        value.title = "edited"
        await store.saveAll([value])
        let stored = try #require(await store.fetch(Assignment.self, id: sync.id))
        #expect(stored.value.title == "edited")
        #expect(stored.unknownFields["mentorName"] == "Dr Patel")
    }
}

/// §3.5: `fields` is a partial. Applying one must merge into the stored body, never replace it.
@Suite("Partial field updates merge, they do not replace")
struct PartialFieldUpdateTests {
    // Captured once: the sample mints fresh subtask ids on every access.
    private let stored = StoredRecord(
        SampleRecords.assignment, unknownFields: ["mentorName": "Dr Patel", "revisionPlan": ["x": 1]])

    @Test("a field absent from the partial is left alone, known and unknown alike")
    func absentFieldsUntouched() throws {
        let merged = try RecordFields.applying(["status": "review"], to: stored)
        #expect(merged.value.status == .review)
        #expect(merged.value.title == stored.value.title)
        #expect(merged.value.rubricText == stored.value.rubricText)
        #expect(merged.value.wordLimit == 2500)
        #expect(merged.value.subtasks == stored.value.subtasks)
        #expect(merged.value.sync == stored.value.sync)
        #expect(merged.unknownFields == stored.unknownFields)
    }

    @Test("a null in the partial clears a known optional; absence does not")
    func nullClearsAbsenceKeeps() throws {
        let cleared = try RecordFields.applying(["rubricText": .null], to: stored)
        #expect(cleared.value.rubricText == nil)
        #expect(cleared.value.briefText == stored.value.briefText)
        let untouched = try RecordFields.applying(["title": "Renamed"], to: stored)
        #expect(untouched.value.rubricText == stored.value.rubricText)
    }

    @Test("a partial can set a known optional that was nil, and the value is not mistaken for unknown")
    func setsNilOptional() throws {
        #expect(stored.value.grade == nil)
        let merged = try RecordFields.applying(["grade": 74, "feedback": "Strong"], to: stored)
        #expect(merged.value.grade == 74)
        #expect(merged.value.feedback == "Strong")
        #expect(merged.unknownFields["grade"] == nil)
        #expect(merged.unknownFields.count == 2)
    }

    @Test("unknown fields in a partial are added, updated or removed without touching the others")
    func unknownFieldsMerge() throws {
        let merged = try RecordFields.applying(
            ["mentorName": "Dr Rao", "cohortTag": "2026A", "revisionPlan": .null], to: stored)
        #expect(merged.unknownFields == ["mentorName": "Dr Rao", "cohortTag": "2026A"])
        #expect(merged.value == stored.value)
    }

    @Test("an empty partial is a no-op")
    func emptyPartial() throws {
        let merged = try RecordFields.applying([:], to: stored)
        #expect(merged == stored)
    }

    @Test("the merged record round-trips through the store and back to the wire intact")
    func throughTheStore() async throws {
        let db = try Database.inMemory()
        try await db.save(stored)
        let current = try #require(try await db.fetch(Assignment.self, id: stored.id))
        let merged = try RecordFields.applying(["status": "submitted", "cohortTag": "2026A"], to: current)
        try await db.save(merged)
        let reloaded = try #require(try await db.fetch(Assignment.self, id: stored.id))
        let wire = try RecordFields.fields(of: reloaded)
        #expect(wire["status"] == "submitted")
        #expect(wire["title"] == .string(stored.value.title))
        #expect(wire["mentorName"] == "Dr Patel")
        #expect(wire["cohortTag"] == "2026A")
        #expect(wire["revisionPlan"] == ["x": 1])
    }
}
