import Foundation
import Observation
import StudyBotCore

/// Revision (§6.4 Study): the decks and cards, today's queue, and the Leitner answer.
/// Intervals of 1, 3, 7, 16 and 35 days; a correct answer promotes a box and an incorrect
/// one resets to box 1 and counts a lapse. The queue is what is due today and nothing more;
/// finishing it ends the session.
@MainActor
@Observable
public final class RevisionStore {
    public private(set) var decks: [Deck] = []
    public private(set) var cards: [Card] = []
    public private(set) var lastError: String?
    public var didWrite: (@MainActor () -> Void)?

    private let store: any RecordStore
    private let deviceID: String
    private let now: @Sendable () -> Date

    public init(store: any RecordStore, deviceID: String, now: @escaping @Sendable () -> Date = { Date() }) {
        self.store = store
        self.deviceID = deviceID
        self.now = now
    }

    public func load() async {
        do {
            decks = try await store.fetchAll(Deck.self, includeDeleted: false).map(\.value)
            cards = try await store.fetchAll(Card.self, includeDeleted: false).map(\.value)
            lastError = nil
        } catch {
            lastError = "Couldn't read the cards: \(error.localizedDescription)"
        }
    }

    // MARK: The queue

    /// Cards due on or before `day`: the longest overdue first, then the lowest box, so the
    /// shakiest knowledge comes up first. Deterministic, so the same queue on both Macs.
    public func queue(on day: LocalDay) -> [Card] {
        cards.filter { LocalDay($0.dueDate) <= day }
            .sorted { ($0.dueDate, $0.box, $0.front) < ($1.dueDate, $1.box, $1.front) }
    }

    /// When the next card falls due after `day`, or nil when there are no cards ahead.
    public func nextDueDay(after day: LocalDay) -> LocalDay? {
        cards.map { LocalDay($0.dueDate) }.filter { $0 > day }.min()
    }

    /// The cards with the most lapses, for the Weak areas strip. None when nothing has lapsed.
    public func weakAreas(limit: Int = 3) -> [Card] {
        cards.filter { $0.lapses > 0 }
            .sorted { ($0.lapses, $0.front) > ($1.lapses, $1.front) }
            .prefix(limit).map { $0 }
    }

    public func deck(for card: Card) -> Deck? {
        decks.first { $0.id == card.deckID }
    }

    // MARK: Answering

    /// The card after `correct` or not, scheduled from `day`: the pure rule, for the tests and
    /// the store alike.
    public static func answered(_ card: Card, correct: Bool, on day: LocalDay) -> Card {
        var next = card
        if correct {
            next.box = min(card.box + 1, Card.intervals.count)
        } else {
            next.box = 1
            next.lapses += 1
        }
        next.dueDate = day.adding(days: next.intervalDays).date
        return next
    }

    /// Records the answer. The card leaves today's queue at once; the write follows, and if
    /// it fails the card comes back with the reason.
    public func answer(_ cardID: UUID, correct: Bool, on day: LocalDay) async {
        guard let index = cards.firstIndex(where: { $0.id == cardID }) else { return }
        let before = cards[index]
        var next = RevisionStore.answered(before, correct: correct, on: day)
        next.sync.markEdited(at: now(), by: deviceID)
        cards[index] = next

        var studied: Deck?
        if let deckIndex = decks.firstIndex(where: { $0.id == before.deckID }) {
            decks[deckIndex].lastStudied = now()
            decks[deckIndex].sync.markEdited(at: now(), by: deviceID)
            studied = decks[deckIndex]
        }
        do {
            try await store.saveAll([next])
            if let studied { try await store.saveAll([studied]) }
            lastError = nil
            didWrite?()
        } catch {
            cards[index] = before
            lastError = DiskSpace.saveFailureMessage(for: error, subject: "The answer")
        }
    }
}
