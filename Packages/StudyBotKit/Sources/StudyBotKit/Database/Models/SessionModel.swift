import Foundation
import StudyBotCore
import SwiftData

extension StudyBotSchemaV1 {
    /// Persisted form of `Session`. See `SyncRecordModel` for the shape.
    @Model
    final class SessionModel: SyncRecordModel {
        typealias Value = Session

        @Attribute(.unique) var id: UUID
        var createdAt: Date
        var updatedAt: Date
        var version: Int
        var baseVersion: Int
        var seq: Int
        var deletedAt: Date?
        var dirty: Bool
        /// The whole `Session`, encoded by `RecordCoding`.
        var body: Data
        /// Fields from a newer build, encoded by `RecordCoding`. Round-tripped, never dropped.
        var unknownFields: Data?
        // Index columns, derived from the body on every write.
        var moduleID: UUID?
        var programmeEventID: UUID?
        var date: Date

        init(value: Session, unknownFields: Data?) throws {
            id = value.sync.id
            createdAt = value.sync.createdAt
            updatedAt = value.sync.updatedAt
            version = value.sync.version
            baseVersion = value.sync.baseVersion
            seq = value.sync.seq
            deletedAt = value.sync.deletedAt
            dirty = value.sync.dirty
            moduleID = value.moduleID
            programmeEventID = value.programmeEventID
            date = value.date
            body = try RecordCoding.encode(value)
            self.unknownFields = unknownFields
        }

        func update(value: Session, unknownFields: Data?) throws {
            createdAt = value.sync.createdAt
            updatedAt = value.sync.updatedAt
            version = value.sync.version
            baseVersion = value.sync.baseVersion
            seq = value.sync.seq
            deletedAt = value.sync.deletedAt
            dirty = value.sync.dirty
            moduleID = value.moduleID
            programmeEventID = value.programmeEventID
            date = value.date
            body = try RecordCoding.encode(value)
            self.unknownFields = unknownFields
        }

        static func predicate(id: UUID) -> Predicate<SessionModel> {
            #Predicate { $0.id == id }
        }

        static var dirtyPredicate: Predicate<SessionModel> {
            #Predicate { $0.dirty == true }
        }

        static var livePredicate: Predicate<SessionModel> {
            #Predicate { $0.deletedAt == nil }
        }
    }
}
