import Foundation

/// One record in the sync envelope (spec §3.5). The same shape travels both ways: the
/// client pushes it with `baseVersion`, the server returns it in `changes` with the
/// server-assigned `version` and `seq` filled in.
///
/// `fields` is a **partial**: only what changed. An older client that omits fields it does
/// not know about therefore cannot erase them, and because the values are `JSONValue` an
/// unknown field received from a newer build is round-tripped rather than dropped (§3.10a).
public struct SyncRecord: Codable, Hashable, Sendable {
    /// The record's wire type, e.g. `"assignment"` (`Syncable.recordType`).
    public var type: String
    public var id: UUID
    /// The server version this edit was made against. `0` for a record the server has never seen.
    public var baseVersion: Int
    /// Client wall clock; used only for last-write-wins.
    public var updatedAt: Date
    /// Tombstone. Present and non-null means the record is deleted.
    public var deletedAt: Date?
    /// Only the changed fields, by model property name.
    public var fields: [String: JSONValue]
    /// Server-assigned version. Absent on push, present on records the server returns.
    public var version: Int?
    /// Server sequence number. Absent on push, present on records the server returns.
    public var seq: Int?
    /// The device that wrote this version. Absent on push (the request carries it once);
    /// present on records the server returns, so a client can run the same tie-break the
    /// server ran when a pulled change meets a local edit it has not pushed yet (§4).
    public var deviceID: String?

    public init(
        type: String,
        id: UUID,
        baseVersion: Int,
        updatedAt: Date,
        deletedAt: Date? = nil,
        fields: [String: JSONValue],
        version: Int? = nil,
        seq: Int? = nil,
        deviceID: String? = nil
    ) {
        self.type = type
        self.id = id
        self.baseVersion = baseVersion
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.fields = fields
        self.version = version
        self.seq = seq
        self.deviceID = deviceID
    }

    /// Whether this record is a tombstone.
    public var isDeleted: Bool { deletedAt != nil }
}
