import Foundation
import StudyBotCore
import StudyBotKit
import Testing

@Suite("ProgrammeCalendarImporter — §3.12 row 1, idempotent re-import")
struct ProgrammeCalendarImporterTests {
    private let firstImport = RealCalendar.importedAt
    private var secondImport: Date { firstImport.addingTimeInterval(86_400 * 30) }

    /// Everything about an event except when it was last seen.
    private func shape(_ event: ProgrammeEvent) -> String {
        "\(event.id)|\(LocalDay(event.startDate))|\(LocalDay(event.endDate))|\(event.kind)|\(event.title)|\(event.moduleCodes)|\(event.cancelledAt.map { "\($0)" } ?? "-")"
    }

    @Test("a first import of the real file adds all 156 events")
    func firstImportAddsEverything() throws {
        let outcome = try ProgrammeCalendarImporter.importCalendar(
            try BundledProgrammeCalendar.data(), into: [], now: firstImport)
        #expect(outcome.events.count == 156)
        #expect(outcome.added.count == 156)
        #expect(outcome.updated.isEmpty)
        #expect(outcome.cancelled.isEmpty)
        #expect(outcome.issues.isEmpty)
        #expect(outcome.changedAnything)
    }

    @Test("re-importing the same file changes nothing but the last-seen stamp")
    func reimportIsIdempotent() throws {
        let data = try BundledProgrammeCalendar.data()
        let first = try ProgrammeCalendarImporter.importCalendar(data, into: [], now: firstImport)
        let second = try ProgrammeCalendarImporter.importCalendar(data, into: first.events, now: secondImport)
        #expect(!second.changedAnything)
        #expect(second.unchangedCount == 156)
        #expect(second.events.count == 156)
        #expect(second.events.map(shape) == first.events.map(shape))
        #expect(second.events.allSatisfy { $0.lastImportedAt == secondImport })
        #expect(Set(second.events.map(\.id)) == Set(first.events.map(\.id)))
    }

    @Test("a changed date updates in place and keeps the same id")
    func changedDateUpdatesInPlace() throws {
        let original = try RealCalendar.events()
        let uid = "dtsl6-2026-assignment-2026-10-15@programme.calendar"
        var moved = original
        let index = try #require(moved.firstIndex { $0.sourceUID == uid })
        let oldID = moved[index].id
        moved[index].startDate = LocalDay(year: 2026, month: 10, day: 22).date
        moved[index].endDate = moved[index].startDate

        let outcome = ProgrammeCalendarImporter.merge(existing: original, incoming: moved, now: secondImport)
        #expect(outcome.updated == [oldID])
        #expect(outcome.added.isEmpty)
        #expect(outcome.cancelled.isEmpty)
        #expect(outcome.unchangedCount == 155)
        let updated = try #require(outcome.events.first { $0.sourceUID == uid })
        #expect(updated.id == oldID)
        #expect(LocalDay(updated.startDate) == LocalDay(year: 2026, month: 10, day: 22))
        #expect(!updated.isCancelled)
    }

    @Test("a removed event is marked cancelled, not deleted, and its id survives for attached notes")
    func removedEventIsCancelled() throws {
        let original = try RealCalendar.events()
        let uid = "dtsl6-2026-online-lectures-2026-09-28@programme.calendar"
        let removedID = try #require(original.first { $0.sourceUID == uid }).id
        let withoutOne = original.filter { $0.sourceUID != uid }

        // A session the user attached to that event before the calendar was reissued.
        let note = Session(
            sync: .new(at: firstImport), title: "Programming week 1", programmeEventID: removedID,
            date: firstImport, liveNotes: "- first lecture")

        let outcome = ProgrammeCalendarImporter.merge(
            existing: original, incoming: withoutOne, now: secondImport)
        #expect(outcome.cancelled == [removedID])
        #expect(outcome.events.count == 156, "cancelled rows stay in the set")
        let cancelled = try #require(outcome.events.first { $0.sourceUID == uid })
        #expect(cancelled.isCancelled)
        #expect(cancelled.cancelledAt == secondImport)
        #expect(cancelled.id == note.programmeEventID, "the note still points at a real event")

        // Importing the trimmed file again does not re-cancel or otherwise change anything.
        let again = ProgrammeCalendarImporter.merge(
            existing: outcome.events, incoming: withoutOne, now: secondImport)
        #expect(!again.changedAnything)
    }

    @Test("an event that comes back after being cancelled is restored with the same id")
    func cancelledEventRestored() throws {
        let original = try RealCalendar.events()
        let uid = "dtsl6-2026-gateway-2029-06-14@programme.calendar"
        let withoutGateway = original.filter { $0.sourceUID != uid }
        let cancelledState = ProgrammeCalendarImporter.merge(
            existing: original, incoming: withoutGateway, now: secondImport)
        let restoredState = ProgrammeCalendarImporter.merge(
            existing: cancelledState.events, incoming: original, now: secondImport.addingTimeInterval(60))
        let gateway = try #require(restoredState.events.first { $0.sourceUID == uid })
        #expect(restoredState.restored == [gateway.id])
        #expect(!gateway.isCancelled)
        #expect(gateway.id == ProgrammeEvent.stableID(forSourceUID: uid))
    }

    @Test("new events in a reissued calendar are added alongside the existing ones")
    func newEventsAdded() throws {
        let original = try RealCalendar.events()
        var reissued = original
        reissued.append(
            ProgrammeEvent(
                startDate: LocalDay(year: 2027, month: 2, day: 1).date,
                endDate: LocalDay(year: 2027, month: 2, day: 1).date,
                kind: .online, title: "Online lectures", moduleCodes: ["COM1013DA"],
                sourceUID: "dtsl6-2026-online-lectures-2027-02-01-extra@programme.calendar",
                lastImportedAt: secondImport))
        let outcome = ProgrammeCalendarImporter.merge(
            existing: original, incoming: reissued, now: secondImport)
        #expect(outcome.added.count == 1)
        #expect(outcome.events.count == 157)
        #expect(outcome.unchangedCount == 156)
    }

    @Test("the merged set is sorted by start date")
    func sorted() throws {
        let outcome = try ProgrammeCalendarImporter.importCalendar(
            try BundledProgrammeCalendar.data(), into: [], now: firstImport)
        let starts = outcome.events.map(\.startDate)
        #expect(starts == starts.sorted())
    }
}
