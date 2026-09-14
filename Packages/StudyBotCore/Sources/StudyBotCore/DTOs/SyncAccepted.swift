import Foundation

/// A pushed record the server accepted (spec §3.5 `accepted`). The client copies `version`
/// and `seq` into its `SyncMetadata` and clears `dirty`.
public struct SyncAccepted: Codable, Hashable, Sendable {
    public var id: UUID
    public var version: Int
    public var seq: Int
    /// When the client's write won a last-write-wins race against a concurrent server
    /// edit, the losing server version is archived and named here, so nothing is lost
    /// silently in either direction (§3.4).
    public var archivedAs: String?

    public init(id: UUID, version: Int, seq: Int, archivedAs: String? = nil) {
        self.id = id
        self.version = version
        self.seq = seq
        self.archivedAs = archivedAs
    }
}
