import Foundation
import StudyBotCore
import SwiftData

extension StudyBotSchemaV1 {
    /// Persisted form of `Deck`. See `SyncRecordModel` for the shape.
    @Model
    final class DeckModel: SyncRecordModel {
        typealias Value = Deck

        @Attribute(.unique) var id: UUID
        var createdAt: Date
        var updatedAt: Date
        var version: Int
        var baseVersion: Int
        var seq: Int
        var deletedAt: Date?
        var dirty: Bool
        /// The whole `Deck`, encoded by `RecordCoding`.
        var body: Data
        /// Fields from a newer build, encoded by `RecordCoding`. Round-tripped, never dropped.
        var unknownFields: Data?
        // Index columns, derived from the body on every write.
        var moduleID: UUID?
        var sessionID: UUID?

        init(value: Deck, unknownFields: Data?) throws {
            id = value.sync.id
            createdAt = value.sync.createdAt
            updatedAt = value.sync.updatedAt
            version = value.sync.version
            baseVersion = value.sync.baseVersion
            seq = value.sync.seq
            deletedAt = value.sync.deletedAt
            dirty = value.sync.dirty
            moduleID = value.moduleID
            sessionID = value.sessionID
            body = try RecordCoding.encode(value)
            self.unknownFields = unknownFields
        }

        func update(value: Deck, unknownFields: Data?) throws {
            createdAt = value.sync.createdAt
            updatedAt = value.sync.updatedAt
            version = value.sync.version
            baseVersion = value.sync.baseVersion
            seq = value.sync.seq
            deletedAt = value.sync.deletedAt
            dirty = value.sync.dirty
            moduleID = value.moduleID
            sessionID = value.sessionID
            body = try RecordCoding.encode(value)
            self.unknownFields = unknownFields
        }

        static func predicate(id: UUID) -> Predicate<DeckModel> {
            #Predicate { $0.id == id }
        }

        static var dirtyPredicate: Predicate<DeckModel> {
            #Predicate { $0.dirty == true }
        }

        static var livePredicate: Predicate<DeckModel> {
            #Predicate { $0.deletedAt == nil }
        }
    }
}
