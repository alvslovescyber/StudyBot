import Foundation
import StudyBotCore
import SwiftData

extension StudyBotSchemaV1 {
    /// Persisted form of `OTJEntry`. See `SyncRecordModel` for the shape.
    @Model
    final class OTJEntryModel: SyncRecordModel {
        typealias Value = OTJEntry

        @Attribute(.unique) var id: UUID
        var createdAt: Date
        var updatedAt: Date
        var version: Int
        var baseVersion: Int
        var seq: Int
        var deletedAt: Date?
        var dirty: Bool
        /// The whole `OTJEntry`, encoded by `RecordCoding`.
        var body: Data
        /// Fields from a newer build, encoded by `RecordCoding`. Round-tripped, never dropped.
        var unknownFields: Data?
        // Index columns, derived from the body on every write.
        var date: Date
        var sessionID: UUID?
        var isSubmittedToProvider: Bool

        init(value: OTJEntry, unknownFields: Data?) throws {
            id = value.sync.id
            createdAt = value.sync.createdAt
            updatedAt = value.sync.updatedAt
            version = value.sync.version
            baseVersion = value.sync.baseVersion
            seq = value.sync.seq
            deletedAt = value.sync.deletedAt
            dirty = value.sync.dirty
            date = value.date
            sessionID = value.sessionID
            isSubmittedToProvider = value.isSubmittedToProvider
            body = try RecordCoding.encode(value)
            self.unknownFields = unknownFields
        }

        func update(value: OTJEntry, unknownFields: Data?) throws {
            createdAt = value.sync.createdAt
            updatedAt = value.sync.updatedAt
            version = value.sync.version
            baseVersion = value.sync.baseVersion
            seq = value.sync.seq
            deletedAt = value.sync.deletedAt
            dirty = value.sync.dirty
            date = value.date
            sessionID = value.sessionID
            isSubmittedToProvider = value.isSubmittedToProvider
            body = try RecordCoding.encode(value)
            self.unknownFields = unknownFields
        }

        static func predicate(id: UUID) -> Predicate<OTJEntryModel> {
            #Predicate { $0.id == id }
        }

        static var dirtyPredicate: Predicate<OTJEntryModel> {
            #Predicate { $0.dirty == true }
        }

        static var livePredicate: Predicate<OTJEntryModel> {
            #Predicate { $0.deletedAt == nil }
        }
    }
}
