import Foundation

/// Body of `POST /v1/sync` (spec §3.5): the client's dirty records plus its current cursor,
/// so one round trip both pushes and pulls.
public struct SyncPushRequest: Codable, Hashable, Sendable {
    public var schemaVersion: Int
    /// The pushing device, as a stable identifier string.
    public var deviceID: String
    /// The highest `seq` the client has already applied.
    public var cursor: Int
    public var records: [SyncRecord]

    public init(
        schemaVersion: Int = SyncSchema.current,
        deviceID: String,
        cursor: Int,
        records: [SyncRecord]
    ) {
        self.schemaVersion = schemaVersion
        self.deviceID = deviceID
        self.cursor = cursor
        self.records = records
    }
}
