import Foundation
import StudyBotCore
import SwiftData

extension StudyBotSchemaV1 {
    /// Persisted form of `Evidence`. See `SyncRecordModel` for the shape.
    @Model
    final class EvidenceModel: SyncRecordModel {
        typealias Value = Evidence

        @Attribute(.unique) var id: UUID
        var createdAt: Date
        var updatedAt: Date
        var version: Int
        var baseVersion: Int
        var seq: Int
        var deletedAt: Date?
        var dirty: Bool
        var deviceID: String
        /// The whole `Evidence`, encoded by `RecordCoding`.
        var body: Data
        /// Fields from a newer build, encoded by `RecordCoding`. Round-tripped, never dropped.
        var unknownFields: Data?
        // Promoted index columns (§4): the only fields the store can query, sort or filter on.
        // Derived from the body on every write.
        var date: Date
        var isWorkConfidential: Bool
        var source: String
        var assignmentID: UUID?

        init(value: Evidence, unknownFields: Data?) throws {
            id = value.sync.id
            createdAt = value.sync.createdAt
            updatedAt = value.sync.updatedAt
            version = value.sync.version
            baseVersion = value.sync.baseVersion
            seq = value.sync.seq
            deletedAt = value.sync.deletedAt
            dirty = value.sync.dirty
            deviceID = value.sync.deviceID
            date = value.date
            isWorkConfidential = value.isWorkConfidential
            source = value.source.rawValue
            assignmentID = value.assignmentID
            body = try RecordCoding.encode(value)
            self.unknownFields = unknownFields
        }

        func update(value: Evidence, unknownFields: Data?) throws {
            createdAt = value.sync.createdAt
            updatedAt = value.sync.updatedAt
            version = value.sync.version
            baseVersion = value.sync.baseVersion
            seq = value.sync.seq
            deletedAt = value.sync.deletedAt
            dirty = value.sync.dirty
            deviceID = value.sync.deviceID
            date = value.date
            isWorkConfidential = value.isWorkConfidential
            source = value.source.rawValue
            assignmentID = value.assignmentID
            body = try RecordCoding.encode(value)
            self.unknownFields = unknownFields
        }

        static func predicate(id: UUID) -> Predicate<EvidenceModel> {
            #Predicate { $0.id == id }
        }

        static var dirtyPredicate: Predicate<EvidenceModel> {
            #Predicate { $0.dirty == true }
        }

        static var livePredicate: Predicate<EvidenceModel> {
            #Predicate { $0.deletedAt == nil }
        }
    }
}
