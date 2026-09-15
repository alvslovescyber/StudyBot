import Foundation
import StudyBotCore
import SwiftData

extension StudyBotSchemaV1 {
    /// Persisted form of `Module`. See `SyncRecordModel` for the shape.
    @Model
    final class ModuleModel: SyncRecordModel {
        typealias Value = Module

        @Attribute(.unique) var id: UUID
        var createdAt: Date
        var updatedAt: Date
        var version: Int
        var baseVersion: Int
        var seq: Int
        var deletedAt: Date?
        var dirty: Bool
        /// The whole `Module`, encoded by `RecordCoding`.
        var body: Data
        /// Fields from a newer build, encoded by `RecordCoding`. Round-tripped, never dropped.
        var unknownFields: Data?
        // Index columns, derived from the body on every write.
        var code: String
        var year: Int
        var isArchived: Bool

        init(value: Module, unknownFields: Data?) throws {
            id = value.sync.id
            createdAt = value.sync.createdAt
            updatedAt = value.sync.updatedAt
            version = value.sync.version
            baseVersion = value.sync.baseVersion
            seq = value.sync.seq
            deletedAt = value.sync.deletedAt
            dirty = value.sync.dirty
            code = value.code
            year = value.year
            isArchived = value.isArchived
            body = try RecordCoding.encode(value)
            self.unknownFields = unknownFields
        }

        func update(value: Module, unknownFields: Data?) throws {
            createdAt = value.sync.createdAt
            updatedAt = value.sync.updatedAt
            version = value.sync.version
            baseVersion = value.sync.baseVersion
            seq = value.sync.seq
            deletedAt = value.sync.deletedAt
            dirty = value.sync.dirty
            code = value.code
            year = value.year
            isArchived = value.isArchived
            body = try RecordCoding.encode(value)
            self.unknownFields = unknownFields
        }

        static func predicate(id: UUID) -> Predicate<ModuleModel> {
            #Predicate { $0.id == id }
        }

        static var dirtyPredicate: Predicate<ModuleModel> {
            #Predicate { $0.dirty == true }
        }

        static var livePredicate: Predicate<ModuleModel> {
            #Predicate { $0.deletedAt == nil }
        }
    }
}
