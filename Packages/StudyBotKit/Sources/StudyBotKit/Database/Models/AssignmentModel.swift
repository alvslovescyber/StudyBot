import Foundation
import StudyBotCore
import SwiftData

extension StudyBotSchemaV1 {
    /// Persisted form of `Assignment`. See `SyncRecordModel` for the shape.
    @Model
    final class AssignmentModel: SyncRecordModel {
        typealias Value = Assignment

        @Attribute(.unique) var id: UUID
        var createdAt: Date
        var updatedAt: Date
        var version: Int
        var baseVersion: Int
        var seq: Int
        var deletedAt: Date?
        var dirty: Bool
        var deviceID: String
        /// The whole `Assignment`, encoded by `RecordCoding`.
        var body: Data
        /// Fields from a newer build, encoded by `RecordCoding`. Round-tripped, never dropped.
        var unknownFields: Data?
        // Promoted index columns (§4): the only fields the store can query, sort or filter on.
        // Derived from the body on every write.
        var status: String
        var moduleID: UUID?
        var priority: String
        var dueDate: Date?
        var termID: UUID?
        var grade: Double?
        var draftSource: String
        var programmeEventID: UUID?

        init(value: Assignment, unknownFields: Data?) throws {
            id = value.sync.id
            createdAt = value.sync.createdAt
            updatedAt = value.sync.updatedAt
            version = value.sync.version
            baseVersion = value.sync.baseVersion
            seq = value.sync.seq
            deletedAt = value.sync.deletedAt
            dirty = value.sync.dirty
            deviceID = value.sync.deviceID
            status = value.status.rawValue
            moduleID = value.moduleID
            priority = value.priority.rawValue
            dueDate = value.dueDate
            termID = value.termID
            grade = value.grade
            draftSource = value.draftSource.rawValue
            programmeEventID = value.programmeEventID
            body = try RecordCoding.encode(value)
            self.unknownFields = unknownFields
        }

        func update(value: Assignment, unknownFields: Data?) throws {
            createdAt = value.sync.createdAt
            updatedAt = value.sync.updatedAt
            version = value.sync.version
            baseVersion = value.sync.baseVersion
            seq = value.sync.seq
            deletedAt = value.sync.deletedAt
            dirty = value.sync.dirty
            deviceID = value.sync.deviceID
            status = value.status.rawValue
            moduleID = value.moduleID
            priority = value.priority.rawValue
            dueDate = value.dueDate
            termID = value.termID
            grade = value.grade
            draftSource = value.draftSource.rawValue
            programmeEventID = value.programmeEventID
            body = try RecordCoding.encode(value)
            self.unknownFields = unknownFields
        }

        static func predicate(id: UUID) -> Predicate<AssignmentModel> {
            #Predicate { $0.id == id }
        }

        static var dirtyPredicate: Predicate<AssignmentModel> {
            #Predicate { $0.dirty == true }
        }

        static var livePredicate: Predicate<AssignmentModel> {
            #Predicate { $0.deletedAt == nil }
        }
    }
}
