import Foundation

/// Response to `GET /v1/sync?since={seq}&limit=500` (spec §3.4, §3.5): records with
/// `seq > since`, oldest first, plus the new cursor. The client paginates until `hasMore` is false.
public struct SyncPullResponse: Codable, Hashable, Sendable {
    public var cursor: Int
    public var changes: [SyncRecord]
    public var hasMore: Bool

    /// The page size the client requests and the server caps at.
    public static let pageSize = 500

    public init(cursor: Int, changes: [SyncRecord], hasMore: Bool) {
        self.cursor = cursor
        self.changes = changes
        self.hasMore = hasMore
    }
}
