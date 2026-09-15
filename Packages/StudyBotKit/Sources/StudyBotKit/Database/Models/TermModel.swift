import Foundation
import StudyBotCore
import SwiftData

extension StudyBotSchemaV1 {
    /// Persisted form of `Term`. See `SyncRecordModel` for the shape.
    @Model
    final class TermModel: SyncRecordModel {
        typealias Value = Term

        @Attribute(.unique) var id: UUID
        var createdAt: Date
        var updatedAt: Date
        var version: Int
        var baseVersion: Int
        var seq: Int
        var deletedAt: Date?
        var dirty: Bool
        /// The whole `Term`, encoded by `RecordCoding`.
        var body: Data
        /// Fields from a newer build, encoded by `RecordCoding`. Round-tripped, never dropped.
        var unknownFields: Data?
        // Index columns, derived from the body on every write.
        var year: Int
        var number: Int
        var startDate: Date
        var endDate: Date

        init(value: Term, unknownFields: Data?) throws {
            id = value.sync.id
            createdAt = value.sync.createdAt
            updatedAt = value.sync.updatedAt
            version = value.sync.version
            baseVersion = value.sync.baseVersion
            seq = value.sync.seq
            deletedAt = value.sync.deletedAt
            dirty = value.sync.dirty
            year = value.year
            number = value.number
            startDate = value.startDate
            endDate = value.endDate
            body = try RecordCoding.encode(value)
            self.unknownFields = unknownFields
        }

        func update(value: Term, unknownFields: Data?) throws {
            createdAt = value.sync.createdAt
            updatedAt = value.sync.updatedAt
            version = value.sync.version
            baseVersion = value.sync.baseVersion
            seq = value.sync.seq
            deletedAt = value.sync.deletedAt
            dirty = value.sync.dirty
            year = value.year
            number = value.number
            startDate = value.startDate
            endDate = value.endDate
            body = try RecordCoding.encode(value)
            self.unknownFields = unknownFields
        }

        static func predicate(id: UUID) -> Predicate<TermModel> {
            #Predicate { $0.id == id }
        }

        static var dirtyPredicate: Predicate<TermModel> {
            #Predicate { $0.dirty == true }
        }

        static var livePredicate: Predicate<TermModel> {
            #Predicate { $0.deletedAt == nil }
        }
    }
}
