import Foundation
import StudyBotCore
import SwiftData

extension StudyBotSchemaV1 {
    /// Persisted form of `Settings`. See `SyncRecordModel` for the shape.
    @Model
    final class SettingsModel: SyncRecordModel {
        typealias Value = Settings

        @Attribute(.unique) var id: UUID
        var createdAt: Date
        var updatedAt: Date
        var version: Int
        var baseVersion: Int
        var seq: Int
        var deletedAt: Date?
        var dirty: Bool
        /// The whole `Settings`, encoded by `RecordCoding`.
        var body: Data
        /// Fields from a newer build, encoded by `RecordCoding`. Round-tripped, never dropped.
        var unknownFields: Data?

        init(value: Settings, unknownFields: Data?) throws {
            id = value.sync.id
            createdAt = value.sync.createdAt
            updatedAt = value.sync.updatedAt
            version = value.sync.version
            baseVersion = value.sync.baseVersion
            seq = value.sync.seq
            deletedAt = value.sync.deletedAt
            dirty = value.sync.dirty
            body = try RecordCoding.encode(value)
            self.unknownFields = unknownFields
        }

        func update(value: Settings, unknownFields: Data?) throws {
            createdAt = value.sync.createdAt
            updatedAt = value.sync.updatedAt
            version = value.sync.version
            baseVersion = value.sync.baseVersion
            seq = value.sync.seq
            deletedAt = value.sync.deletedAt
            dirty = value.sync.dirty
            body = try RecordCoding.encode(value)
            self.unknownFields = unknownFields
        }

        static func predicate(id: UUID) -> Predicate<SettingsModel> {
            #Predicate { $0.id == id }
        }

        static var dirtyPredicate: Predicate<SettingsModel> {
            #Predicate { $0.dirty == true }
        }

        static var livePredicate: Predicate<SettingsModel> {
            #Predicate { $0.deletedAt == nil }
        }
    }
}
