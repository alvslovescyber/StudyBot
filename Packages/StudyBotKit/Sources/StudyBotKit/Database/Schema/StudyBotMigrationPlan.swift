import SwiftData

/// The ordered list of schema versions and the stages between them (§16 "Migrations").
///
/// There is one version today, so there are no stages. The plan exists now so that adding
/// V2 is "append a schema and a stage", not "introduce migrations into a store that already
/// holds a year of notes". `MigrationTests` loads a store written by the previous version.
enum StudyBotMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [StudyBotSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }

    /// The schema this build reads and writes.
    static var current: any VersionedSchema.Type {
        StudyBotSchemaV1.self
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
