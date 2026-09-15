import Foundation

/// What the server currently holds for one record: the authoritative version, its sequence
/// number, and the whole field set. Both the Vapor server and the in-memory server used by
/// the sync tests store exactly this, so the merge rule can be one pure function.
public struct ServerRecordState: Codable, Hashable, Sendable {
    public var type: String
    public var id: UUID
    public var version: Int
    public var seq: Int
    public var updatedAt: Date
    public var deletedAt: Date?
    /// The device that wrote this version; empty if unknown.
    public var deviceID: String
    /// Every field of the record as last written, known or not to any particular build.
    public var fields: [String: JSONValue]

    public init(
        type: String, id: UUID, version: Int, seq: Int, updatedAt: Date, deletedAt: Date? = nil,
        deviceID: String, fields: [String: JSONValue]
    ) {
        self.type = type
        self.id = id
        self.version = version
        self.seq = seq
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.deviceID = deviceID
        self.fields = fields
    }

    /// The state as a wire record for `changes`: `baseVersion` is the version itself, since
    /// the server is the source of truth.
    public var wireRecord: SyncRecord {
        SyncRecord(
            type: type, id: id, baseVersion: version, updatedAt: updatedAt, deletedAt: deletedAt,
            fields: fields, version: version, seq: seq, deviceID: deviceID)
    }

    /// The metadata `LastWriteWins` compares.
    public var comparable: SyncMetadata {
        SyncMetadata(
            id: id, createdAt: updatedAt, updatedAt: updatedAt, version: version, baseVersion: version,
            seq: seq, deletedAt: deletedAt, dirty: false, deviceID: deviceID)
    }
}
