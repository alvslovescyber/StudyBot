import Foundation
import StudyBotCore
import SwiftData

extension StudyBotSchemaV2 {
    /// Persisted form of `ConflictLoser`. Local-only, never synced.
    @Model
    final class ConflictLoserModel {
        @Attribute(.unique) var id: UUID
        var recordType: String
        var recordID: UUID
        var losingUpdatedAt: Date
        var archivedAt: Date
        var replacedByVersion: Int
        var serverArchiveID: String?
        /// The losing `SyncRecord`, encoded by `RecordCoding`.
        var body: Data

        init(value: ConflictLoser) throws {
            id = value.id
            recordType = value.record.type
            recordID = value.record.id
            losingUpdatedAt = value.record.updatedAt
            archivedAt = value.archivedAt
            replacedByVersion = value.replacedByVersion
            serverArchiveID = value.serverArchiveID
            body = try RecordCoding.encode(value.record)
        }

        func value() throws -> ConflictLoser {
            ConflictLoser(
                id: id, record: try RecordCoding.decode(SyncRecord.self, from: body), archivedAt: archivedAt,
                replacedByVersion: replacedByVersion, serverArchiveID: serverArchiveID)
        }
    }
}
