import SwiftData

/// The ordered list of schema versions and the stages between them (§16 "Migrations").
///
/// V1 shipped with milestone two; V2 adds the sync engine's two local tables. Every new
/// version appends a schema and a stage here and a test in `MigrationTests` that opens a
/// store written by the previous version.
enum StudyBotMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [StudyBotSchemaV1.self, StudyBotSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    /// Two tables added, nothing changed: lightweight.
    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: StudyBotSchemaV1.self, toVersion: StudyBotSchemaV2.self)

    /// The schema this build reads and writes.
    static var current: any VersionedSchema.Type {
        StudyBotSchemaV2.self
    }
}

/// Current-schema names, so the rest of the package never spells out a version.
typealias ModuleModel = StudyBotSchemaV1.ModuleModel
typealias TermModel = StudyBotSchemaV1.TermModel
typealias AssignmentModel = StudyBotSchemaV1.AssignmentModel
typealias SessionModel = StudyBotSchemaV1.SessionModel
typealias DeckModel = StudyBotSchemaV1.DeckModel
typealias CardModel = StudyBotSchemaV1.CardModel
typealias QuizAttemptModel = StudyBotSchemaV1.QuizAttemptModel
typealias KSBModel = StudyBotSchemaV1.KSBModel
typealias EvidenceModel = StudyBotSchemaV1.EvidenceModel
typealias OTJEntryModel = StudyBotSchemaV1.OTJEntryModel
typealias ProposalModel = StudyBotSchemaV1.ProposalModel
typealias SettingsModel = StudyBotSchemaV1.SettingsModel
typealias AttachmentModel = StudyBotSchemaV1.AttachmentModel
typealias AIRunModel = StudyBotSchemaV1.AIRunModel
typealias ProgrammeEventModel = StudyBotSchemaV1.ProgrammeEventModel
typealias NoteRevisionModel = StudyBotSchemaV1.NoteRevisionModel
typealias ConflictLoserModel = StudyBotSchemaV2.ConflictLoserModel
typealias SyncStateModel = StudyBotSchemaV2.SyncStateModel
