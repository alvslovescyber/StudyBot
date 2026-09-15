import Fluent
import Foundation
import StudyBotCore
import Vapor

/// `conflict_archive` (§3.4): every losing version, whichever side lost. Named `c_<id>` on the
/// wire and fetched back whole through `GET /v1/sync/archive/c_<id>`.
final class ConflictArchiveRow: Model, @unchecked Sendable {
    static let schema = "conflict_archive"

    @ID(custom: "id") var id: Int?
    @Field(key: "record_id") var recordID: UUID
    @Field(key: "record_type") var recordType: String
    /// The losing `SyncRecord` as JSON text.
    @Field(key: "body") var body: String
    @Field(key: "losing_updated_at") var losingUpdatedAt: Double
    @Field(key: "archived_at") var archivedAt: Double

    init() {}

    init(losing: SyncRecord, archivedAt: Date) throws {
        recordID = losing.id
        recordType = losing.type
        body = try JSONText.encode(losing)
        losingUpdatedAt = losing.updatedAt.timeIntervalSince1970
        self.archivedAt = archivedAt.timeIntervalSince1970
    }

    /// The wire name, e.g. `c_5512`.
    var archiveID: String { "c_\(id ?? 0)" }

    static func rowID(from archiveID: String) -> Int? {
        guard archiveID.hasPrefix("c_") else { return nil }
        return Int(archiveID.dropFirst(2))
    }

    func archivedRecord() throws -> ArchivedRecord {
        ArchivedRecord(
            id: archiveID, record: try JSONText.decode(SyncRecord.self, from: body),
            archivedAt: Date(timeIntervalSince1970: archivedAt))
    }
}
