import Foundation
import StudyBotCore
import StudyBotKit
import Testing

@MainActor
@Suite("RevisionStore — the queue and the Leitner answer")
struct RevisionStoreTests {
    private nonisolated static let t0 = SyncClient.t0
    private nonisolated static let today = LocalDay(year: 2026, month: 10, day: 6)

    private func card(_ front: String, box: Int = 1, due: LocalDay = today, lapses: Int = 0, deck: UUID)
        -> Card
    {
        Card(
            sync: .new(at: Self.t0), deckID: deck, front: front, back: "back of \(front)", box: box,
            dueDate: due.date,
            lapses: lapses)
    }

    private func makeStore(_ records: any RecordStore, cards: [Card], deck: Deck) async throws
        -> RevisionStore
    {
        try await records.saveAll([deck])
        try await records.saveAll(cards)
        let store = RevisionStore(store: records, deviceID: "air", now: { Self.today.date })
        await store.load()
        return store
    }

    @Test("the queue is what is due today or earlier, longest overdue and lowest box first")
    func queue() async throws {
        let deck = Deck(sync: .new(at: Self.t0), title: "Week 1")
        let cards = [
            card("later", due: Self.today.adding(days: 3), deck: deck.id),
            card("today b", box: 2, deck: deck.id),
            card("today a", box: 1, deck: deck.id),
            card("overdue", box: 3, due: Self.today.adding(days: -2), deck: deck.id),
        ]
        let store = try await makeStore(InMemoryRecordStore(), cards: cards, deck: deck)
        #expect(store.queue(on: Self.today).map(\.front) == ["overdue", "today a", "today b"])
        #expect(store.nextDueDay(after: Self.today) == Self.today.adding(days: 3))
        #expect(store.queue(on: Self.today.adding(days: -5)).isEmpty)
        #expect(store.weakAreas().isEmpty, "nothing has lapsed")
        #expect(store.deck(for: cards[0])?.title == "Week 1")
    }

    @Test("Got it promotes a box and reschedules by its interval; box 5 stays at 35 days")
    func promote() {
        let deck = UUID()
        let one = RevisionStore.answered(card("q", box: 1, deck: deck), correct: true, on: Self.today)
        #expect(one.box == 2 && LocalDay(one.dueDate) == Self.today.adding(days: 3) && one.lapses == 0)
        let four = RevisionStore.answered(card("q", box: 4, deck: deck), correct: true, on: Self.today)
        #expect(four.box == 5 && LocalDay(four.dueDate) == Self.today.adding(days: 35))
        let five = RevisionStore.answered(card("q", box: 5, deck: deck), correct: true, on: Self.today)
        #expect(five.box == 5 && LocalDay(five.dueDate) == Self.today.adding(days: 35))
    }

    @Test("Again resets to box 1, counts a lapse, and comes back tomorrow")
    func lapse() {
        let reset = RevisionStore.answered(
            card("q", box: 4, lapses: 1, deck: UUID()), correct: false, on: Self.today)
        #expect(reset.box == 1 && reset.lapses == 2)
        #expect(LocalDay(reset.dueDate) == Self.today.adding(days: 1))
    }

    @Test(
        "an answer leaves the queue at once, is written with the deck's lastStudied, and surfaces weak areas")
    func answer() async throws {
        let records = InMemoryRecordStore()
        let deck = Deck(sync: .new(at: Self.t0), title: "Week 1")
        let cards = [card("a", deck: deck.id), card("b", deck: deck.id), card("c", lapses: 2, deck: deck.id)]
        let store = try await makeStore(records, cards: cards, deck: deck)
        var wrote = 0
        store.didWrite = { wrote += 1 }

        await store.answer(cards[0].id, correct: true, on: Self.today)
        await store.answer(cards[1].id, correct: false, on: Self.today)
        #expect(
            store.queue(on: Self.today).map(\.front) == ["c"], "answered cards are gone until they are due")
        #expect(wrote == 2)
        let saved = try #require(try await records.fetch(Card.self, id: cards[1].id)?.value)
        #expect(saved.box == 1 && saved.lapses == 1 && saved.sync.dirty)
        #expect(try await records.fetch(Deck.self, id: deck.id)?.value.lastStudied == Self.today.date)
        #expect(store.weakAreas().map(\.front) == ["c", "b"])
        #expect(store.nextDueDay(after: Self.today) == Self.today.adding(days: 1))
    }

    @Test("when the write fails the card comes back into the queue with the reason")
    func revert() async throws {
        let records = FailingRecordStore()
        let deck = Deck(sync: .new(at: Self.t0), title: "Week 1")
        let cards = [card("a", deck: deck.id)]
        let store = try await makeStore(records, cards: cards, deck: deck)
        await records.setFailing(true)
        await store.answer(cards[0].id, correct: true, on: Self.today)
        #expect(store.queue(on: Self.today).map(\.front) == ["a"])
        #expect(store.lastError == "The answer could not be saved. Your disk is full.")
    }
}
