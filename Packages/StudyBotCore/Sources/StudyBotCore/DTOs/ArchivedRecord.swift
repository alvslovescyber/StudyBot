import Foundation

/// A losing version kept in the server's `conflict_archive` (spec §3.4), as returned by
/// `GET /v1/sync/archive/{id}`. Named by the `archivedAs` on an accepted or conflicted push,
/// so a replaced page of notes is always one request away.
public struct ArchivedRecord: Codable, Hashable, Sendable {
    /// The archive id, e.g. `c_5512`.
    public var id: String
    /// The losing version, complete: every field it had, its `updatedAt` and its writer.
    public var record: SyncRecord
    public var archivedAt: Date

    public init(id: String, record: SyncRecord, archivedAt: Date) {
        self.id = id
        self.record = record
        self.archivedAt = archivedAt
    }
}
