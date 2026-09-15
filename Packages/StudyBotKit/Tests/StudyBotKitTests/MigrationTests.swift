import Foundation
import StudyBotCore
import SwiftData
import Testing

@testable import StudyBotKit

/// §16: every schema version ships a test that loads a store written by the previous version.
/// There is one version today, so this writes a store with `StudyBotSchemaV1` directly (no
/// migration plan) and opens it through `Database`, which applies the plan. When V2 arrives,
/// keep this test and add one that writes V1 and reads V2.
@Suite("Migrations — §3.12 row 'Migrations'")
struct MigrationTests {
    @Test("the plan lists every version in order and the current one is last")
    func planShape() {
        #expect(StudyBotMigrationPlan.schemas.count == 1)
        #expect(
            StudyBotMigrationPlan.schemas.last.map(ObjectIdentifier.init)
                == ObjectIdentifier(StudyBotSchemaV1.self))
        #expect(ObjectIdentifier(StudyBotMigrationPlan.current) == ObjectIdentifier(StudyBotSchemaV1.self))
        #expect(StudyBotSchemaV1.versionIdentifier == Schema.Version(1, 0, 0))
        #expect(StudyBotMigrationPlan.stages.isEmpty)
        #expect(StudyBotSchemaV1.models.count == 16)
    }

    @Test("a store written by schema V1 opens through the migration plan with its data intact")
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
    }
}
