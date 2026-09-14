import Foundation

/// A flashcard on a Leitner schedule (spec §4). Intervals of 1, 3, 7, 16 and 35 days.
/// Correct promotes a box, incorrect resets to box 1 and increments `lapses`.
public struct Card: Syncable {
    public static let recordType = "card"

    /// Leitner review intervals in days, indexed by box number 1–5.
    public static let intervals = [1, 3, 7, 16, 35]

    public var sync: SyncMetadata
    public var deckID: UUID
    public var front: String
    public var back: String
    /// Which note line it came from.
    public var source: String?
    /// Leitner box, 1–5.
    public var box: Int
    /// Date-only, at Europe/London midnight.
    public var dueDate: Date
    public var lapses: Int

    public init(
        sync: SyncMetadata,
        deckID: UUID,
        front: String,
        back: String,
        source: String? = nil,
        box: Int = 1,
        dueDate: Date,
        lapses: Int = 0
    ) {
        self.sync = sync
        self.deckID = deckID
        self.front = front
        self.back = back
        self.source = source
        self.box = min(max(box, 1), Card.intervals.count)
        self.dueDate = dueDate
        self.lapses = lapses
    }

    /// The review interval, in days, for the card's current box.
    public var intervalDays: Int { Card.intervals[box - 1] }
}
