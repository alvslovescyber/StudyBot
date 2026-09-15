import Foundation
import StudyBotCore
import SwiftData
import Testing

@testable import StudyBotKit

/// §16: every schema version ships a test that loads a store written by the previous version.
/// `loadsPreviousVersion` writes a store with `StudyBotSchemaV1` directly, the way a
/// milestone-two or -three build did, and opens it through `Database`, which migrates it to V2.
@Suite("Migrations — §3.12 row 'Migrations'")
struct MigrationTests {
    @Test("the plan lists every version in order and the current one is last")
    func planShape() {
        #expect(StudyBotMigrationPlan.schemas.count == 2)
        #expect(
            StudyBotMigrationPlan.schemas.last.map(ObjectIdentifier.init)
                == ObjectIdentifier(StudyBotSchemaV2.self))
        #expect(ObjectIdentifier(StudyBotMigrationPlan.current) == ObjectIdentifier(StudyBotSchemaV2.self))
        #expect(StudyBotSchemaV1.versionIdentifier == Schema.Version(1, 0, 0))
        #expect(StudyBotSchemaV2.versionIdentifier == Schema.Version(2, 0, 0))
        #expect(StudyBotMigrationPlan.stages.count == 1)
        #expect(StudyBotSchemaV1.models.count == 16)
        #expect(StudyBotSchemaV2.models.count == 18)
    }

    @Test("a store written by schema V1 migrates to V2 with its data intact and the new tables usable")
    func loadsPreviousVersion() async throws {
        let temp = try TemporaryStore()
        defer { temp.remove() }

        let assignment = SampleRecords.assignment
        let event = SampleRecords.programmeEvent
        let revision = NoteRevision(
            sessionID: SampleRecords.sessionID, body: "v1 body", capturedAt: SampleRecords.now,
            reason: .preSync)

        // Write with the V1 schema and no migration plan, the way a V1 build did.
        do {
            let schema = Schema(versionedSchema: StudyBotSchemaV1.self)
            let container = try ModelContainer(
                for: schema, configurations: [ModelConfiguration(schema: schema, url: temp.url)])
            let context = ModelContext(container)
            context.insert(
                try StudyBotSchemaV1.AssignmentModel(
                    value: assignment,
                    unknownFields: try RecordCoding.encodeUnknownFields(["legacyFlag": true])))
            context.insert(try StudyBotSchemaV1.ProgrammeEventModel(value: event))
            context.insert(StudyBotSchemaV1.NoteRevisionModel(value: revision))
            try context.save()
        }

        // Open with the current plan.
        let db = try Database.onDisk(at: temp.url)
        let stored = try #require(try await db.fetch(Assignment.self, id: assignment.id))
        #expect(stored.value == assignment)
        #expect(stored.unknownFields == ["legacyFlag": true])
        #expect(try await db.programmeEvent(sourceUID: event.sourceUID) == event)
        #expect(try await db.noteRevisions(for: SampleRecords.sessionID) == [revision])

        // The V2 tables exist and work in the migrated store.
        #expect(try await db.syncState() == SyncState())
        var state = SyncState()
        state.cursor = 42
        try await db.saveSyncState(state)
        #expect(try await db.syncState().cursor == 42)
        #expect(try await db.conflictLosers(for: assignment.id).isEmpty)
    }
}
