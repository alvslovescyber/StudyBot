import Foundation
import StudyBotCore
import SwiftData

extension StudyBotSchemaV1 {
    /// Persisted form of `Card`. See `SyncRecordModel` for the shape.
    @Model
    final class CardModel: SyncRecordModel {
        typealias Value = Card

        @Attribute(.unique) var id: UUID
        var createdAt: Date
        var updatedAt: Date
        var version: Int
        var baseVersion: Int
        var seq: Int
        var deletedAt: Date?
        var dirty: Bool
        /// The whole `Card`, encoded by `RecordCoding`.
        var body: Data
        /// Fields from a newer build, encoded by `RecordCoding`. Round-tripped, never dropped.
        var unknownFields: Data?
        // Index columns, derived from the body on every write.
        var deckID: UUID
        var dueDate: Date
        var box: Int

        init(value: Card, unknownFields: Data?) throws {
            id = value.sync.id
            createdAt = value.sync.createdAt
            updatedAt = value.sync.updatedAt
            version = value.sync.version
            baseVersion = value.sync.baseVersion
            seq = value.sync.seq
            deletedAt = value.sync.deletedAt
            dirty = value.sync.dirty
            deckID = value.deckID
            dueDate = value.dueDate
            box = value.box
            body = try RecordCoding.encode(value)
            self.unknownFields = unknownFields
        }

        func update(value: Card, unknownFields: Data?) throws {
            createdAt = value.sync.createdAt
            updatedAt = value.sync.updatedAt
            version = value.sync.version
            baseVersion = value.sync.baseVersion
            seq = value.sync.seq
            deletedAt = value.sync.deletedAt
            dirty = value.sync.dirty
            deckID = value.deckID
            dueDate = value.dueDate
            box = value.box
            body = try RecordCoding.encode(value)
            self.unknownFields = unknownFields
        }

        static func predicate(id: UUID) -> Predicate<CardModel> {
            #Predicate { $0.id == id }
        }

        static var dirtyPredicate: Predicate<CardModel> {
            #Predicate { $0.dirty == true }
        }

        static var livePredicate: Predicate<CardModel> {
            #Predicate { $0.deletedAt == nil }
        }
    }
}
