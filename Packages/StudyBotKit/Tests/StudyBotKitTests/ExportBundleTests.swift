import Foundation
import StudyBotCore
import StudyBotKit
import Testing

/// §16: "Import of that bundle into a fresh install, tested end to end, because an export
/// nobody has ever restored is not a backup." Export, wipe, restore, assert nothing was lost.
@Suite("ExportBundle — export, wipe, restore")
struct ExportBundleTests {
    private struct Seeded {
        let session: Session
        let revision: NoteRevision
        let loser: ConflictLoser
    }

    /// Everything the app can hold: every type, unknown fields, notes, revisions, losers,
    /// programme events, a tombstone, sync state.
    private func seed(_ source: Database) async throws -> Seeded {
        try await source.save(SampleRecords.module)
        try await source.save(SampleRecords.term)
        try await source.save(
            StoredRecord(SampleRecords.assignment, unknownFields: ["mentorName": "Dr Patel"]))
        var session = SampleRecords.session
        session.liveNotes = "- sets\nASK: does order matter\n"
        session.openQuestions = ["does order matter"]
        try await source.save(session)
        try await source.save(SampleRecords.deck)
        try await source.save(SampleRecords.card)
        try await source.save(SampleRecords.quizAttempt)
        try await source.save(SampleRecords.ksb)
        try await source.save(SampleRecords.evidence)
        try await source.save(SampleRecords.otjEntry)
        try await source.save(SampleRecords.proposal)
        try await source.save(SampleRecords.settings)
        try await source.save(SampleRecords.attachment)
        try await source.save(SampleRecords.aiRun)
        var deleted = SampleRecords.evidence
        deleted.sync.id = UUID()
        deleted.sync.markDeleted(at: SampleRecords.now)
        try await source.save(deleted)
        try await source.saveProgrammeEvents([SampleRecords.programmeEvent])
        let revision = NoteRevision(
            sessionID: session.id, body: "earlier", capturedAt: SampleRecords.now, reason: .idleSnapshot)
        try await source.addNoteRevision(revision)
        let loser = ConflictLoser(
            record: SyncRecord(
                type: "session", id: session.id, baseVersion: 1, updatedAt: SampleRecords.now,
                fields: ["liveNotes": "other Mac"]),
            archivedAt: SampleRecords.now, replacedByVersion: 2, serverArchiveID: "c_9")
        try await source.restoreConflictLosers([loser])
        var state = SyncState()
        state.cursor = 4_821
        state.serverURL = URL(string: "https://studybot.example.com")
        state.deviceName = "Air"
        try await source.saveSyncState(state)
        return Seeded(session: session, revision: revision, loser: loser)
    }

    /// Every type equal, metadata included, tombstones included.
    private func assertSameRecords(_ source: Database, _ restored: Database) async throws {
        func same<T: Persistable>(_ type: T.Type) async throws {
            let before = try await source.fetchAll(type, includeDeleted: true).sorted {
                $0.id.uuidString < $1.id.uuidString
            }
            let after = try await restored.fetchAll(type, includeDeleted: true).sorted {
                $0.id.uuidString < $1.id.uuidString
            }
            #expect(before == after, "\(T.recordType)")
        }
        try await same(Module.self)
        try await same(Term.self)
        try await same(Assignment.self)
        try await same(Session.self)
        try await same(Deck.self)
        try await same(Card.self)
        try await same(QuizAttempt.self)
        try await same(KSB.self)
        try await same(Evidence.self)
        try await same(OTJEntry.self)
        try await same(Proposal.self)
        try await same(Settings.self)
        try await same(Attachment.self)
        try await same(AIRun.self)
    }

    @Test("a full store round-trips through the bundle with nothing lost")
    func roundTrip() async throws {
        let source = try Database.inMemory()
        let seeded = try await seed(source)
        let (session, revision, loser) = (seeded.session, seeded.revision, seeded.loser)

        let temp = try TemporaryStore()
        defer { temp.remove() }
        let (folder, manifest) = try await ExportBundle.write(
            from: source, into: temp.directory, appVersion: "0.6.0", deviceID: "air", now: SampleRecords.now)

        // The bundle is readable without StudyBot.
        let files = try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted()
        #expect(files.contains("manifest.json") && files.contains("README.txt") && files.contains("notes"))
        let noteFile = folder.appendingPathComponent("notes/\(ExportBundle.markdownFileName(for: session))")
        let markdown = try String(contentsOf: noteFile, encoding: .utf8)
        #expect(markdown.hasPrefix("# Sets and relations\n"))
        #expect(markdown.contains("- sets\nASK: does order matter"))
        #expect(markdown.contains("## Questions to ask\n\n- does order matter"))
        #expect(
            manifest.counts["assignment"] == 1 && manifest.counts["evidence"] == 2
                && manifest.counts["notes"] == 1)
        #expect(manifest.cursor == 4_821)
        let assignmentsJSON = try String(
            contentsOf: folder.appendingPathComponent("records/assignment.json"), encoding: .utf8)
        #expect(assignmentsJSON.contains("\"mentorName\" : \"Dr Patel\""), "unknown fields are in the export")

        // Wipe: a brand-new store. Restore into it.
        let restored = try Database.inMemory()
        let summary = try await ExportBundle.restore(from: folder, into: restored)
        #expect(summary.records == 15)
        #expect(summary.programmeEvents == 1 && summary.noteRevisions == 1 && summary.conflictLosers == 1)

        try await assertSameRecords(source, restored)
        #expect(
            try await restored.fetchAll(Evidence.self, includeDeleted: false).count == 1,
            "the tombstone stays a tombstone")
        #expect(
            try await restored.fetch(Assignment.self, id: SampleRecords.assignmentID)?.unknownFields == [
                "mentorName": "Dr Patel"
            ])
        #expect(try await restored.programmeEvent(sourceUID: "uid") == SampleRecords.programmeEvent)
        #expect(try await restored.noteRevisions(for: session.id) == [revision])
        #expect(try await restored.conflictLosers(for: session.id) == [loser])
        let restoredState = try await restored.syncState()
        #expect(restoredState.cursor == 4_821 && restoredState.deviceName == "Air")

        // Restoring twice changes nothing.
        _ = try await ExportBundle.restore(from: folder, into: restored)
        #expect(try await restored.noteRevisions(for: session.id).count == 1)
    }

    @Test("a folder that is not an export is refused with a reason")
    func notAnExport() async throws {
        let temp = try TemporaryStore()
        defer { temp.remove() }
        let db = try Database.inMemory()
        await #expect(throws: ExportError.notAnExport(temp.directory.lastPathComponent)) {
            try await ExportBundle.restore(from: temp.directory, into: db)
        }
    }
}
