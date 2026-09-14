import Foundation

/// A flashcard deck (spec §4). Cards are separate records carrying `deckID`.
public struct Deck: Syncable {
    public static let recordType = "deck"

    public var sync: SyncMetadata
    public var title: String
    /// The session the deck was generated from, if any (the spec's `lecture?`).
    public var sessionID: UUID?
    public var moduleID: UUID?
    public var lastStudied: Date?

    public init(
        sync: SyncMetadata,
        title: String,
        sessionID: UUID? = nil,
        moduleID: UUID? = nil,
        lastStudied: Date? = nil
    ) {
        self.sync = sync
        self.title = title
        self.sessionID = sessionID
        self.moduleID = moduleID
        self.lastStudied = lastStudied
    }
}
