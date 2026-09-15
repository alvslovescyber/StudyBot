import SwiftData

/// Schema version 2: V1 plus the two local-only tables the sync engine needs, `ConflictLoser`
/// and `SyncState`. Nothing in V1 changed, so V1's model classes are reused as they are and
/// the stage is lightweight. `MigrationTests` opens a V1 store through the plan.
enum StudyBotSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        StudyBotSchemaV1.models + [ConflictLoserModel.self, SyncStateModel.self]
    }
}
