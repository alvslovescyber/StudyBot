import Foundation

/// The sync fields every syncable record carries (spec §4, "Every syncable model carries the
/// same eight fields"), plus `deviceID`, the writer of the current version, which the
/// deterministic tie-break needs (§4, `LastWriteWins`). Defined once here and embedded in
/// each model.
///
/// Why a struct rather than copied properties: one definition means the sync engine, the
/// server and the tests all agree on exactly what "syncable" means, and a renamed field
/// breaks the build on both sides instead of failing silently at runtime.
public struct SyncMetadata: Codable, Hashable, Sendable {
    /// Client-generated, stable forever. Never reassigned, not even after a conflict.
    public var id: UUID

    /// When the record was first created on any device.
    public var createdAt: Date

    /// Bumped on every local edit. Drives last-write-wins conflict resolution (§3.4).
    public var updatedAt: Date

    /// Server-assigned; increments on each accepted write. `0` until the first sync.
    public var version: Int

    /// The server `version` this local edit was made against. Lets the server detect a
    /// concurrent edit rather than blindly overwriting.
    public var baseVersion: Int

    /// Server sequence number: the sync cursor. `0` until the server has seen the record.
    /// A monotonic counter, never a timestamp, so clock skew cannot reorder changes.
    public var seq: Int

    /// Tombstone. Rows are never hard-deleted; a set `deletedAt` is what "deleted" means.
    public var deletedAt: Date?

    /// Local changes not yet acknowledged by the server.
    public var dirty: Bool

    /// The device that wrote the current `updatedAt`. Breaks ties when two devices edit at
    /// the same instant: lower id wins, lexicographically, on every machine alike. Empty for
    /// records written before devices had ids; `LastWriteWins` treats empty as highest.
    public var deviceID: String

    public init(
        id: UUID = UUID(),
        createdAt: Date,
        updatedAt: Date,
        version: Int = 0,
        baseVersion: Int = 0,
        seq: Int = 0,
        deletedAt: Date? = nil,
        dirty: Bool = true,
        deviceID: String = ""
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.version = version
        self.baseVersion = baseVersion
        self.seq = seq
        self.deletedAt = deletedAt
        self.dirty = dirty
        self.deviceID = deviceID
    }

    /// Metadata for a record created locally right now: version 0, dirty, not deleted.
    public static func new(id: UUID = UUID(), at now: Date, deviceID: String = "") -> SyncMetadata {
        SyncMetadata(id: id, createdAt: now, updatedAt: now, deviceID: deviceID)
    }

    /// Whether the record has been tombstoned.
    public var isDeleted: Bool { deletedAt != nil }

    /// Records a local edit at `now` by `deviceID`: bumps `updatedAt`, marks the record dirty.
    /// `baseVersion` is left alone; it still names the server version the edit was made against.
    /// Passing nil for `deviceID` keeps the current writer.
    public mutating func markEdited(at now: Date, by deviceID: String? = nil) {
        updatedAt = now
        dirty = true
        if let deviceID {
            self.deviceID = deviceID
        }
    }

    /// Tombstones the record at `now`. Idempotent: a second call keeps the first `deletedAt`.
    public mutating func markDeleted(at now: Date, by deviceID: String? = nil) {
        if deletedAt == nil {
            deletedAt = now
        }
        markEdited(at: now, by: deviceID)
    }

    /// Applies the server's acknowledgement of a pushed write (§3.5 `accepted`).
    public mutating func acknowledge(version: Int, seq: Int) {
        self.version = version
        self.baseVersion = version
        self.seq = seq
        dirty = false
    }

    // MARK: Decoding older rows

    private enum CodingKeys: String, CodingKey {
        case id, createdAt, updatedAt, version, baseVersion, seq, deletedAt, dirty, deviceID
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        version = try container.decode(Int.self, forKey: .version)
        baseVersion = try container.decode(Int.self, forKey: .baseVersion)
        seq = try container.decode(Int.self, forKey: .seq)
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
        dirty = try container.decode(Bool.self, forKey: .dirty)
        // Rows written before deviceID existed decode as "unknown writer".
        deviceID = try container.decodeIfPresent(String.self, forKey: .deviceID) ?? ""
    }
}
