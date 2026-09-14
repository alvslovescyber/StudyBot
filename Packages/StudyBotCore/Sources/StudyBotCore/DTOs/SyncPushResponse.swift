import Foundation

/// Response to `POST /v1/sync` (spec §3.5). `accepted`, `conflicts` and `changes` arrive
/// together so one round trip completes a sync. The response is authoritative: the client
/// overwrites local state with it.
public struct SyncPushResponse: Codable, Hashable, Sendable {
    /// The new cursor: the highest `seq` included in `changes`, or the request cursor if none.
    public var cursor: Int
    public var accepted: [SyncAccepted]
    public var conflicts: [SyncConflict]
    /// Records with `seq` greater than the request cursor, oldest first.
    public var changes: [SyncRecord]
    /// Whether more changes exist beyond `cursor`; the client keeps pulling until false.
    public var hasMore: Bool

    public init(
        cursor: Int,
        accepted: [SyncAccepted] = [],
        conflicts: [SyncConflict] = [],
        changes: [SyncRecord] = [],
        hasMore: Bool = false
    ) {
        self.cursor = cursor
        self.accepted = accepted
        self.conflicts = conflicts
        self.changes = changes
        self.hasMore = hasMore
    }
}
