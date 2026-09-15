import Foundation
import StudyBotCore
import SwiftData

extension StudyBotSchemaV1 {
    /// Persisted form of `Attachment`. See `SyncRecordModel` for the shape.
    @Model
    final class AttachmentModel: SyncRecordModel {
        typealias Value = Attachment

        @Attribute(.unique) var id: UUID
        var createdAt: Date
        var updatedAt: Date
        var version: Int
        var baseVersion: Int
        var seq: Int
        var deletedAt: Date?
        var dirty: Bool
        /// The whole `Attachment`, encoded by `RecordCoding`.
        var body: Data
        /// Fields from a newer build, encoded by `RecordCoding`. Round-tripped, never dropped.
        var unknownFields: Data?
        // Index columns, derived from the body on every write.
        var sha256: String?
        var assignmentID: UUID?
        var sessionID: UUID?
        var evidenceID: UUID?

        init(value: Attachment, unknownFields: Data?) throws {
            id = value.sync.id
            createdAt = value.sync.createdAt
            updatedAt = value.sync.updatedAt
            version = value.sync.version
            baseVersion = value.sync.baseVersion
            seq = value.sync.seq
            deletedAt = value.sync.deletedAt
            dirty = value.sync.dirty
            sha256 = value.sha256
            assignmentID = value.assignmentID
            sessionID = value.sessionID
            evidenceID = value.evidenceID
            body = try RecordCoding.encode(value)
            self.unknownFields = unknownFields
        }

        func update(value: Attachment, unknownFields: Data?) throws {
            createdAt = value.sync.createdAt
            updatedAt = value.sync.updatedAt
            version = value.sync.version
            baseVersion = value.sync.baseVersion
            seq = value.sync.seq
            deletedAt = value.sync.deletedAt
            dirty = value.sync.dirty
            sha256 = value.sha256
            assignmentID = value.assignmentID
            sessionID = value.sessionID
            evidenceID = value.evidenceID
            body = try RecordCoding.encode(value)
            self.unknownFields = unknownFields
        }

        static func predicate(id: UUID) -> Predicate<AttachmentModel> {
            #Predicate { $0.id == id }
        }

        static var dirtyPredicate: Predicate<AttachmentModel> {
            #Predicate { $0.dirty == true }
        }

        static var livePredicate: Predicate<AttachmentModel> {
            #Predicate { $0.deletedAt == nil }
        }
    }
}
