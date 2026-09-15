import Foundation
import StudyBotCore
import SwiftData

extension StudyBotSchemaV1 {
    /// Persisted form of `QuizAttempt`. See `SyncRecordModel` for the shape.
    @Model
    final class QuizAttemptModel: SyncRecordModel {
        typealias Value = QuizAttempt

        @Attribute(.unique) var id: UUID
        var createdAt: Date
        var updatedAt: Date
        var version: Int
        var baseVersion: Int
        var seq: Int
        var deletedAt: Date?
        var dirty: Bool
        /// The whole `QuizAttempt`, encoded by `RecordCoding`.
        var body: Data
        /// Fields from a newer build, encoded by `RecordCoding`. Round-tripped, never dropped.
        var unknownFields: Data?
        // Index columns, derived from the body on every write.
        var deckID: UUID?
        var sessionID: UUID?
        var takenAt: Date

        init(value: QuizAttempt, unknownFields: Data?) throws {
            id = value.sync.id
            createdAt = value.sync.createdAt
            updatedAt = value.sync.updatedAt
            version = value.sync.version
            baseVersion = value.sync.baseVersion
            seq = value.sync.seq
            deletedAt = value.sync.deletedAt
            dirty = value.sync.dirty
            deckID = value.deckID
            sessionID = value.sessionID
            takenAt = value.takenAt
            body = try RecordCoding.encode(value)
            self.unknownFields = unknownFields
        }

        func update(value: QuizAttempt, unknownFields: Data?) throws {
            createdAt = value.sync.createdAt
            updatedAt = value.sync.updatedAt
            version = value.sync.version
            baseVersion = value.sync.baseVersion
            seq = value.sync.seq
            deletedAt = value.sync.deletedAt
            dirty = value.sync.dirty
            deckID = value.deckID
            sessionID = value.sessionID
            takenAt = value.takenAt
            body = try RecordCoding.encode(value)
            self.unknownFields = unknownFields
        }

        static func predicate(id: UUID) -> Predicate<QuizAttemptModel> {
            #Predicate { $0.id == id }
        }

        static var dirtyPredicate: Predicate<QuizAttemptModel> {
            #Predicate { $0.dirty == true }
        }

        static var livePredicate: Predicate<QuizAttemptModel> {
            #Predicate { $0.deletedAt == nil }
        }
    }
}
