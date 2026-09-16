import Foundation
import StudyBotCore
import StudyBotKit
import Testing

/// A store whose writes fail on demand, the way SwiftData's do when the volume is full.
actor FailingRecordStore: RecordStore {
    private let inner = InMemoryRecordStore()
    var failWrites = false
    var writeAttempts = 0

    func setFailing(_ failing: Bool) { failWrites = failing }

    func programmeEvents(includeCancelled: Bool) async throws -> [ProgrammeEvent] {
        try await inner.programmeEvents(includeCancelled: includeCancelled)
    }
    func saveProgrammeEvents(_ events: [ProgrammeEvent]) async throws {
        try await inner.saveProgrammeEvents(events)
    }
    func fetchAll<T: Persistable>(_ type: T.Type, includeDeleted: Bool) async throws -> [StoredRecord<T>] {
        try await inner.fetchAll(type, includeDeleted: includeDeleted)
    }
    func saveAll<T: Persistable>(_ values: [T]) async throws {
        writeAttempts += 1
        if failWrites { throw CocoaError(.fileWriteOutOfSpace) }
        try await inner.saveAll(values)
    }
    func fetch<T: Persistable>(_ type: T.Type, id: UUID) async -> StoredRecord<T>? {
        await inner.fetch(type, id: id)
    }
}

/// §16 Reliability: a failed save is impossible to miss and loses nothing.
@MainActor
@Suite("Disk full — §16 Reliability")
struct DiskFullTests {
    private nonisolated static let t0 = SyncClient.t0

    @Test("out-of-space errors are recognised in every shape SwiftData surfaces them")
    func recognisesOutOfSpace() {
        #expect(DiskSpace.isOutOfSpace(CocoaError(.fileWriteOutOfSpace)))
        #expect(DiskSpace.isOutOfSpace(NSError(domain: NSPOSIXErrorDomain, code: Int(ENOSPC))))
        let wrapped = NSError(
            domain: "NSSQLiteErrorDomain", code: 13,
            userInfo: [NSLocalizedDescriptionKey: "database or disk is full"])
        #expect(DiskSpace.isOutOfSpace(wrapped))
        let underlying = NSError(
            domain: NSCocoaErrorDomain, code: 134_030,
            userInfo: [NSUnderlyingErrorKey: NSError(domain: NSPOSIXErrorDomain, code: Int(ENOSPC))])
        #expect(DiskSpace.isOutOfSpace(underlying))
        #expect(!DiskSpace.isOutOfSpace(CocoaError(.fileReadNoPermission)))
        #expect(
            DiskSpace.saveFailureMessage(for: CocoaError(.fileWriteOutOfSpace), subject: "This note")
                == "This note could not be saved. Your disk is full.")
        #expect(DiskSpace.level(freeBytes: 3_000_000_000) == .ok)
        #expect(DiskSpace.level(freeBytes: 1_999_999_999) == .low)
        #expect(DiskSpace.level(freeBytes: 499_999_999) == .critical)
    }

    @Test("a failed write raises the banner, keeps the text, and clears when the disk has room again")
    func failedWriteIsVisibleAndLossless() async throws {
        let records = FailingRecordStore()
        let revisions = FakeRevisionStore()
        let store = NotesStore(
            store: records, revisions: revisions, deviceID: "air", now: { Self.t0 },
            saveDelay: .milliseconds(30), snapshotDelay: .seconds(60))
        let events = try RealCalendar.events()
        let slot = try #require(SessionCatalog.slot(on: RealCalendar.day(2026, 9, 28), in: events))
        let session = await store.open(slot, moduleID: nil)
        #expect(store.saveFailures.isEmpty)

        // The disk fills mid-sentence.
        await records.setFailing(true)
        store.updateLiveNotes(session.id, text: "the lecturer said the exam is open book")
        try await Task.sleep(for: .milliseconds(80))
        #expect(store.saveFailures[session.id] == "This note could not be saved. Your disk is full.")
        #expect(store.hasUnsavedNotes)
        #expect(store.unsavedSessionTitles == ["Online lectures"])
        #expect(
            store.session(id: session.id)?.liveNotes == "the lecturer said the exam is open book",
            "text retained")
        #expect(
            await records.fetch(Session.self, id: session.id)?.value.liveNotes == "",
            "nothing reached the store")

        // Typing on keeps working and keeps the banner.
        store.updateLiveNotes(session.id, text: "the lecturer said the exam is open book, two hours")
        try await Task.sleep(for: .milliseconds(80))
        #expect(store.saveFailures[session.id] != nil)

        // Room again: the retry succeeds, the banner clears, and the latest text is what landed.
        await records.setFailing(false)
        await store.retrySave(session.id)
        #expect(store.saveFailures.isEmpty)
        #expect(!store.hasUnsavedNotes)
        #expect(
            await records.fetch(Session.self, id: session.id)?.value.liveNotes
                == "the lecturer said the exam is open book, two hours")
    }

    @Test("revision snapshots are skipped when the disk is short, and a failing snapshot is silent")
    func snapshotsYield() async throws {
        let records = InMemoryRecordStore()
        let revisions = FakeRevisionStore()
        let store = NotesStore(
            store: records, revisions: revisions, deviceID: "air", now: { Self.t0 },
            saveDelay: .milliseconds(20), snapshotDelay: .milliseconds(60))
        store.snapshotsAllowed = { false }
        let events = try RealCalendar.events()
        let slot = try #require(SessionCatalog.slot(on: RealCalendar.day(2026, 9, 28), in: events))
        let session = await store.open(slot, moduleID: nil)
        store.updateLiveNotes(session.id, text: "notes worth keeping")
        try await Task.sleep(for: .milliseconds(150))
        #expect(await revisions.revisions.isEmpty, "no snapshot below the critical level")
        #expect(
            await records.fetch(Session.self, id: session.id)?.value.liveNotes == "notes worth keeping",
            "the note itself was written")
        #expect(store.lastError == nil)
    }

    @Test("the disk monitor warns once under 2 GB and persistently under 500 MB")
    func monitorLevels() {
        let box = LockedValue<Int64>(3_000_000_000)
        let monitor = DiskMonitor(
            storeURL: URL(fileURLWithPath: "/tmp/x.store"), freeSpace: { _ in box.value })
        monitor.check()
        #expect(monitor.level == .ok && monitor.todayNotice == nil)

        box.value = 1_800_000_000
        monitor.check()
        #expect(monitor.level == .low)
        #expect(monitor.todayNotice == "Your disk has 1.8 GB free. StudyBot needs room to save notes.")
        #expect(monitor.noticeIsDismissible)
        monitor.dismissLowWarning()
        #expect(monitor.todayNotice == nil)
        #expect(monitor.snapshotsAllowed)

        box.value = 300_000_000
        monitor.check()
        #expect(monitor.level == .critical)
        #expect(monitor.todayNotice == "Your disk has 300 MB free. Notes may not save. Free space now.")
        #expect(!monitor.noticeIsDismissible)
        #expect(!monitor.snapshotsAllowed)

        box.value = 5_000_000_000
        monitor.check()
        #expect(monitor.todayNotice == nil)
        box.value = 1_000_000_000
        monitor.check()
        #expect(monitor.todayNotice != nil, "the once-only warning resets after the disk had room")
    }
}

/// A thread-safe mutable box for test closures.
final class LockedValue<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: T
    init(_ value: T) { stored = value }
    var value: T {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }
}
