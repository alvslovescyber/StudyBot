import Foundation

/// What applying one server response did to the store. The engine reads it to decide whether
/// to keep pulling, and tests read it to check the counts.
public struct SyncApplication: Hashable, Sendable {
    /// The cursor after this response.
    public var cursor: Int
    /// Records written or replaced from `changes`.
    public var applied: Int
    /// Local versions archived as `ConflictLoser` because the server's version won.
    public var losersArchived: Int
    /// Changes left alone because the local, unpushed edit would win the same comparison on
    /// the server. They stay dirty and go up on the next push.
    public var keptLocal: Int
    /// The server's cursor is behind ours: it was restored from a backup. Every local record
    /// has been marked dirty so the next push reconciles them (§3.11).
    public var cursorRegressed: Bool
    /// Wire types the server sent that this build has no table for. Kept nowhere: a newer
    /// build's whole new record type is out of reach for an old client, and that is logged,
    /// not silently invented.
    public var unknownTypes: Set<String>

    public init(
        cursor: Int, applied: Int = 0, losersArchived: Int = 0, keptLocal: Int = 0,
        cursorRegressed: Bool = false, unknownTypes: Set<String> = []
    ) {
        self.cursor = cursor
        self.applied = applied
        self.losersArchived = losersArchived
        self.keptLocal = keptLocal
        self.cursorRegressed = cursorRegressed
        self.unknownTypes = unknownTypes
    }
}
