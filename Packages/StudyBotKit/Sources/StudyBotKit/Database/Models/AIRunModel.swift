import Foundation
import StudyBotCore
import SwiftData

extension StudyBotSchemaV1 {
    /// Persisted form of `AIRun`. See `SyncRecordModel` for the shape.
    @Model
    final class AIRunModel: SyncRecordModel {
        typealias Value = AIRun

        @Attribute(.unique) var id: UUID
        var createdAt: Date
        var updatedAt: Date
        var version: Int
        var baseVersion: Int
        var seq: Int
        var deletedAt: Date?
        var dirty: Bool
        /// The whole `AIRun`, encoded by `RecordCoding`.
        var body: Data
        /// Fields from a newer build, encoded by `RecordCoding`. Round-tripped, never dropped.
        var unknownFields: Data?
        // Index columns, derived from the body on every write.
        var capability: String
        var assignmentID: UUID?
        var timestamp: Date

        init(value: AIRun, unknownFields: Data?) throws {
            id = value.sync.id
            createdAt = value.sync.createdAt
            updatedAt = value.sync.updatedAt
            version = value.sync.version
            baseVersion = value.sync.baseVersion
            seq = value.sync.seq
            deletedAt = value.sync.deletedAt
            dirty = value.sync.dirty
            capability = value.capability.rawValue
            assignmentID = value.assignmentID
            timestamp = value.timestamp
            body = try RecordCoding.encode(value)
            self.unknownFields = unknownFields
        }

        func update(value: AIRun, unknownFields: Data?) throws {
            createdAt = value.sync.createdAt
            updatedAt = value.sync.updatedAt
            version = value.sync.version
            baseVersion = value.sync.baseVersion
            seq = value.sync.seq
            deletedAt = value.sync.deletedAt
            dirty = value.sync.dirty
            capability = value.capability.rawValue
            assignmentID = value.assignmentID
            timestamp = value.timestamp
            body = try RecordCoding.encode(value)
            self.unknownFields = unknownFields
        }

        static func predicate(id: UUID) -> Predicate<AIRunModel> {
            #Predicate { $0.id == id }
        }

        static var dirtyPredicate: Predicate<AIRunModel> {
            #Predicate { $0.dirty == true }
        }

        static var livePredicate: Predicate<AIRunModel> {
            #Predicate { $0.deletedAt == nil }
        }
    }
}
