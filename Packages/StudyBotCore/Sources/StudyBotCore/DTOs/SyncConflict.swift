import Foundation

/// A pushed record the server rejected because a newer write won (spec §3.5 `conflicts`).
/// The server's version is authoritative and arrives in `changes`; the client's losing
/// version is archived server-side and kept locally as a `NoteRevision` for 30 days (§3.4).
public struct SyncConflict: Codable, Hashable, Sendable {
    public var id: UUID
    /// The version now current on the server.
    public var serverVersion: Int
    public var resolution: ConflictResolution
    /// Where the losing version was archived. Always present: a conflict never loses data silently.
    public var archivedAs: String

    public init(
        id: UUID, serverVersion: Int, resolution: ConflictResolution = .serverWins, archivedAs: String
    ) {
        self.id = id
        self.serverVersion = serverVersion
        self.resolution = resolution
        self.archivedAs = archivedAs
    }
}

/// How a conflict was resolved. Last write wins by `updatedAt`; a conflict entry is only
/// produced when the server's write was later, so `serverWins` is the normal value.
public enum ConflictResolution: String, Codable, CaseIterable, Hashable, Sendable {
    case serverWins
}
