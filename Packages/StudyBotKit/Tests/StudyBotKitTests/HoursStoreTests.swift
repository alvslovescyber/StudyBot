import Foundation
import StudyBotCore
import StudyBotKit
import Testing

@MainActor
@Suite("HoursStore — the week bar and one-line logging")
struct HoursStoreTests {
    /// Tuesday 6 October 2026, 09:00 London.
    private nonisolated static let tuesday = RealCalendar.day(2026, 10, 6).date.addingTimeInterval(9 * 3_600)

    @Test("a logged line is in the week at once, written, and announced; the week runs Monday to Sunday")
    func log() async throws {
        let records = InMemoryRecordStore()
        let store = HoursStore(store: records, deviceID: "air", now: { Self.tuesday })
        var wrote = 0
        store.didWrite = { wrote += 1 }
        await store.load()
        #expect(store.targetPerWeek == 6)

        let entry = try #require(await store.log("2h project work: rewrote the pipeline checks"))
        #expect(entry.hours == 2 && entry.category == .projectWork)
        #expect(LocalDay(entry.date) == RealCalendar.day(2026, 10, 6))
        #expect(wrote == 1)
        #expect(
            try await records.fetch(OTJEntry.self, id: entry.id)?.value.description
                == "rewrote the pipeline checks")

        _ = await store.log("90m lecture", on: RealCalendar.day(2026, 10, 4))
        let week = store.week(containing: RealCalendar.day(2026, 10, 6))
        #expect(week.days.map(\.day.isoWeekday) == [1, 2, 3, 4, 5, 6, 7])
        #expect(week.start == RealCalendar.day(2026, 10, 5))
        #expect(week.days[1].hours == 2)
        #expect(week.total == 2, "Sunday the 4th belongs to last week")
        #expect(store.week(containing: RealCalendar.day(2026, 10, 4)).total == 1.5)
    }

    @Test("a line without a duration is refused with the hint, and nothing is written")
    func refused() async throws {
        let records = InMemoryRecordStore()
        let store = HoursStore(store: records, deviceID: "air", now: { Self.tuesday })
        #expect(await store.log("project work") == nil)
        #expect(store.lastError == HoursLine.hint)
        #expect(store.entries.isEmpty)
        #expect(try await records.fetchAll(OTJEntry.self, includeDeleted: false).isEmpty)
        #expect(await store.log("30h marathon") == nil)
        #expect(store.lastError == "Can't be more than 24 in a day")
    }

    @Test("when the write fails the entry comes back out and the bar says why")
    func revert() async throws {
        let records = FailingRecordStore()
        let store = HoursStore(store: records, deviceID: "air", now: { Self.tuesday })
        var wrote = 0
        store.didWrite = { wrote += 1 }
        await records.setFailing(true)
        #expect(await store.log("2h project work") == nil)
        #expect(store.entries.isEmpty, "reverted")
        #expect(store.lastError == "The hours could not be saved. Your disk is full.")
        #expect(wrote == 0)

        await records.setFailing(false)
        let entry = try #require(await store.log("2h project work"))
        #expect(store.entries.map(\.id) == [entry.id] && store.lastError == nil)
        await store.delete(entry.id)
        #expect(store.entries.isEmpty)
    }
}
