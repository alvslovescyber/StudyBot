import Fluent
import Foundation
import Vapor

/// `sync_log` (§4 server-only tables): one row per accepted write. Never purged, so the next
/// `seq` is always `max(seq) + 1` even after old tombstones are removed from `records`.
final class SyncLogRow: Model, @unchecked Sendable {
    static let schema = "sync_log"

    @ID(custom: "seq", generatedBy: .user) var id: Int?
    @Field(key: "record_id") var recordID: UUID
    @Field(key: "record_type") var recordType: String
    @Field(key: "device_id") var deviceID: String
    @Field(key: "at") var at: Double

    init() {}

    init(seq: Int, recordID: UUID, recordType: String, deviceID: String, at: Date) {
        id = seq
        self.recordID = recordID
        self.recordType = recordType
        self.deviceID = deviceID
        self.at = at.timeIntervalSince1970
    }
}
