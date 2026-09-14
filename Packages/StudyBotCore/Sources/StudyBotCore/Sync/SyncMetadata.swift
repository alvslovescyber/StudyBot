import Foundation

/// The eight fields every syncable record carries (spec §4, "Every syncable model
/// carries the same eight fields"). Defined once here and embedded in each model.
///
/// Why a struct rather than eight copied properties: one definition means the sync
/// engine, the server and the tests all agree on exactly what "syncable" means, and a
/// renamed field breaks the build on both sides instead of failing silently at runtime.
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

    public init(
        id: UUID = UUID(),
        createdAt: Date,
        updatedAt: Date,
        version: Int = 0,
        baseVersion: Int = 0,
        seq: Int = 0,
        deletedAt: Date? = nil,
        dirty: Bool = true
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.version = version
        self.baseVersion = baseVersion
        self.seq = seq
        self.deletedAt = deletedAt
        self.dirty = dirty
    }

    /// Metadata for a record created locally right now: version 0, dirty, not deleted.
    public static func new(id: UUID = UUID(), at now: Date) -> SyncMetadata {
        SyncMetadata(id: id, createdAt: now, updatedAt: now)
    }

    /// Whether the record has been tombstoned.
    public var isDeleted: Bool { deletedAt != nil }

    /// Records a local edit at `now`: bumps `updatedAt` and marks the record dirty.
    /// `baseVersion` is left alone; it still names the server version the edit was made against.
    public mutating func markEdited(at now: Date) {
        updatedAt = now
        dirty = true
    }

    /// Tombstones the record at `now`. Idempotent: a second call keeps the first `deletedAt`.
    public mutating func markDeleted(at now: Date) {
        if deletedAt == nil {
            deletedAt = now
        }
        markEdited(at: now)
    }

    /// Applies the server's acknowledgement of a pushed write (§3.5 `accepted`).
    public mutating func acknowledge(version: Int, seq: Int) {
        self.version = version
        self.baseVersion = version
        self.seq = seq
        dirty = false
    }
}
