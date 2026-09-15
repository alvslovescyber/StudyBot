import SwiftData

/// Schema version 1. Model classes are declared in extensions of this enum, one per file
/// under `Database/Models`, so a future V2 can redeclare only what changed and the migration
/// plan can name both.
///
/// Rule from §16: every schema change ships a versioned migration stage and a test that
/// loads a store written by the previous version. Never a destructive migration.
enum StudyBotSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            ModuleModel.self,
            TermModel.self,
            AssignmentModel.self,
            SessionModel.self,
            DeckModel.self,
            CardModel.self,
            QuizAttemptModel.self,
            KSBModel.self,
            EvidenceModel.self,
            OTJEntryModel.self,
            ProposalModel.self,
            SettingsModel.self,
            AttachmentModel.self,
            AIRunModel.self,
            ProgrammeEventModel.self,
            NoteRevisionModel.self,
        ]
    }
}
