import Foundation
import StudyBotCore
import SwiftData

extension StudyBotSchemaV1 {
    /// Persisted form of `Proposal`. See `SyncRecordModel` for the shape.
    @Model
    final class ProposalModel: SyncRecordModel {
        typealias Value = Proposal

        @Attribute(.unique) var id: UUID
        var createdAt: Date
        var updatedAt: Date
        var version: Int
        var baseVersion: Int
        var seq: Int
        var deletedAt: Date?
        var dirty: Bool
        /// The whole `Proposal`, encoded by `RecordCoding`.
        var body: Data
        /// Fields from a newer build, encoded by `RecordCoding`. Round-tripped, never dropped.
        var unknownFields: Data?
        // Index columns, derived from the body on every write.
        var kind: String
        var source: String
        var sourceRef: String
        var state: String
        var targetID: UUID?

        init(value: Proposal, unknownFields: Data?) throws {
            id = value.sync.id
            createdAt = value.sync.createdAt
            updatedAt = value.sync.updatedAt
            version = value.sync.version
            baseVersion = value.sync.baseVersion
            seq = value.sync.seq
            deletedAt = value.sync.deletedAt
            dirty = value.sync.dirty
            kind = value.kind.rawValue
            source = value.source.rawValue
            sourceRef = value.sourceRef
            state = value.state.rawValue
            targetID = value.targetID
            body = try RecordCoding.encode(value)
            self.unknownFields = unknownFields
        }

        func update(value: Proposal, unknownFields: Data?) throws {
            createdAt = value.sync.createdAt
            updatedAt = value.sync.updatedAt
            version = value.sync.version
            baseVersion = value.sync.baseVersion
            seq = value.sync.seq
            deletedAt = value.sync.deletedAt
            dirty = value.sync.dirty
            kind = value.kind.rawValue
            source = value.source.rawValue
            sourceRef = value.sourceRef
            state = value.state.rawValue
            targetID = value.targetID
            body = try RecordCoding.encode(value)
            self.unknownFields = unknownFields
        }

        static func predicate(id: UUID) -> Predicate<ProposalModel> {
            #Predicate { $0.id == id }
        }

        static var dirtyPredicate: Predicate<ProposalModel> {
            #Predicate { $0.dirty == true }
        }

        static var livePredicate: Predicate<ProposalModel> {
            #Predicate { $0.deletedAt == nil }
        }
    }
}
