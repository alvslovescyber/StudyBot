import Foundation
import Observation
import StudyBotCore

/// The notes domain store (§3.3 `NotesStore`): sessions and their live notes, transcripts,
/// `ASK:` questions, revisions and conflict losers. Views type into `updateLiveNotes`; the
/// store keeps the in-memory copy current at once, writes to the store once typing pauses,
/// and snapshots a `NoteRevision` after 30 seconds idle (§4), the insurance that matters
/// most in a lecture.
@MainActor
@Observable
public final class NotesStore {
    /// A question collected from a session's `ASK:` lines.
    public struct Question: Identifiable, Hashable, Sendable {
        public let sessionID: UUID
        public let sessionTitle: String
        public let day: LocalDay
        public let text: String
        public var id: String { "\(sessionID)#\(text)" }
    }

    public private(set) var sessions: [UUID: Session] = [:]
    public private(set) var lastError: String?
    /// Sessions whose last write failed, with §16's message. The text is still in `sessions`
    /// and in the editor; the banner stays until a later write succeeds.
    public private(set) var saveFailures: [UUID: String] = [:]
    /// Called after every write the store makes, so the sync engine can run once it settles.
    public var didWrite: (@MainActor () -> Void)?
    /// Whether a revision snapshot may be written now. `DiskMonitor` says no below 500 MB free,
    /// so snapshots never take the last of the room a note write needs (§16).
    public var snapshotsAllowed: @MainActor () -> Bool = { true }

    private let store: any RecordStore
    private let revisions: any NoteRevisionStore
    private let deviceID: String
    private let now: @Sendable () -> Date
    private let saveDelay: Duration
    private let snapshotDelay: Duration
    private var saveTasks: [UUID: Task<Void, Never>] = [:]
    private var snapshotTasks: [UUID: Task<Void, Never>] = [:]
    private var lastSnapshotBody: [UUID: String] = [:]

    public init(
        store: any RecordStore, revisions: any NoteRevisionStore, deviceID: String,
        now: @escaping @Sendable () -> Date = { Date() }, saveDelay: Duration = .milliseconds(800),
        snapshotDelay: Duration = .seconds(30)
    ) {
        self.store = store
        self.revisions = revisions
        self.deviceID = deviceID
        self.now = now
        self.saveDelay = saveDelay
        self.snapshotDelay = snapshotDelay
    }

    // MARK: Loading

    public func load() async {
        do {
            let all = try await store.fetchAll(Session.self, includeDeleted: false).map(\.value)
            sessions = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            lastError = nil
        } catch {
            lastError = "Couldn't read the notes: \(error.localizedDescription)"
        }
    }

    public func session(id: UUID) -> Session? { sessions[id] }

    /// The session for a slot if it has been opened before, else nil. Nothing is created.
    public func session(for slot: SessionSlot) -> Session? { sessions[slot.id] }

    /// Opens a slot's session, creating the record on first open with the stable id both Macs
    /// derive. Creating is a write, so it syncs; an empty session is fine to sync.
    public func open(_ slot: SessionSlot, moduleID: UUID?) async -> Session {
        if let existing = sessions[slot.id] { return existing }
        let created = slot.newSession(moduleID: moduleID, at: now(), deviceID: deviceID)
        sessions[created.id] = created
        await write(created)
        return created
    }

    // MARK: Editing

    /// Every keystroke lands here. The in-memory copy changes now; the store write waits for
    /// typing to pause; the revision snapshot waits for 30 seconds of quiet.
    public func updateLiveNotes(_ sessionID: UUID, text: String) {
        guard var session = sessions[sessionID], session.liveNotes != text else { return }
        session.liveNotes = text
        session.openQuestions = LiveNoteParser.questions(in: text)
        session.sync.markEdited(at: now(), by: deviceID)
        sessions[sessionID] = session
        scheduleSave(sessionID)
        scheduleSnapshot(sessionID)
    }

    public func updateTranscript(_ sessionID: UUID, text: String) {
        guard var session = sessions[sessionID] else { return }
        let value = text.isEmpty ? nil : text
        guard session.transcript != value else { return }
        session.transcript = value
        session.sync.markEdited(at: now(), by: deviceID)
        sessions[sessionID] = session
        scheduleSave(sessionID)
    }

    /// One tap from the session (§4 "What counts as attended").
    public func markAttended(_ sessionID: UUID) async {
        guard var session = sessions[sessionID], !session.markedAttended else { return }
        session.markedAttended = true
        session.sync.markEdited(at: now(), by: deviceID)
        sessions[sessionID] = session
        await write(session)
    }

    /// Appends a line to the session's live notes, as the capture bar does (§6.6). A question
    /// is filed as an `ASK:` line so it joins the questions list.
    public func append(_ text: String, asQuestion: Bool, to sessionID: UUID) {
        guard let session = sessions[sessionID] else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let line = asQuestion && LiveNoteParser.questionText(of: trimmed) == nil ? "ASK: \(trimmed)" : trimmed
        let separator = session.liveNotes.isEmpty || session.liveNotes.hasSuffix("\n") ? "" : "\n"
        updateLiveNotes(sessionID, text: session.liveNotes + separator + line + "\n")
    }

    /// Writes whatever is pending for a session now. Called when a session closes or the app
    /// goes to the background, so nothing waits on a timer that may never fire.
    public func flush(_ sessionID: UUID) async {
        saveTasks[sessionID]?.cancel()
        saveTasks[sessionID] = nil
        guard let session = sessions[sessionID] else { return }
        await write(session)
    }

    public func flushAll() async {
        for id in Array(saveTasks.keys) {
            await flush(id)
        }
    }

    // MARK: Questions (§6.3, §6.6)

    /// Every `ASK:` line across the given sessions, in session date order then note order.
    public func questions(in sessionIDs: [UUID]) -> [Question] {
        sessionIDs.compactMap { sessions[$0] }
            .sorted { $0.date < $1.date }
            .flatMap { session in
                session.openQuestions.map {
                    Question(
                        sessionID: session.id, sessionTitle: session.title, day: LocalDay(session.date),
                        text: $0)
                }
            }
    }

    // MARK: Revisions and losers (§3.4, §4)

    public func revisions(for sessionID: UUID) async -> [NoteRevision] {
        (try? await revisions.noteRevisions(for: sessionID)) ?? []
    }

    /// Versions of this session's notes that lost a sync race in the last 30 days.
    public func conflictLosers(for sessionID: UUID) async -> [ConflictLoser] {
        (try? await revisions.conflictLosers(for: sessionID)) ?? []
    }

    /// Puts an older body back as the live notes. The current text is snapshotted first so
    /// restoring is itself reversible.
    public func restore(body: String, into sessionID: UUID) async {
        guard let current = sessions[sessionID] else { return }
        if current.hasNotes {
            await snapshot(sessionID, body: current.liveNotes, reason: .preSync)
        }
        updateLiveNotes(sessionID, text: body)
        await flush(sessionID)
    }

    /// Whether any note has text the store could not write (§16: never close over unsaved work).
    public var hasUnsavedNotes: Bool { !saveFailures.isEmpty }

    /// The session titles with unsaved text, for the quit warning.
    public var unsavedSessionTitles: [String] {
        saveFailures.keys.compactMap { sessions[$0]?.title }.sorted()
    }

    /// Tries the failed write again, from the banner's button.
    public func retrySave(_ sessionID: UUID) async {
        await flush(sessionID)
    }

    // MARK: Internals

    private func scheduleSave(_ sessionID: UUID) {
        saveTasks[sessionID]?.cancel()
        saveTasks[sessionID] = Task { [weak self, saveDelay] in
            try? await Task.sleep(for: saveDelay)
            guard !Task.isCancelled, let self, let session = self.sessions[sessionID] else { return }
            self.saveTasks[sessionID] = nil
            await self.write(session)
        }
    }

    private func scheduleSnapshot(_ sessionID: UUID) {
        snapshotTasks[sessionID]?.cancel()
        snapshotTasks[sessionID] = Task { [weak self, snapshotDelay] in
            try? await Task.sleep(for: snapshotDelay)
            guard !Task.isCancelled, let self, let session = self.sessions[sessionID] else { return }
            self.snapshotTasks[sessionID] = nil
            guard session.hasNotes, self.lastSnapshotBody[sessionID] != session.liveNotes else { return }
            await self.snapshot(sessionID, body: session.liveNotes, reason: .idleSnapshot)
        }
    }

    /// Snapshots are insurance, never a cost: skipped when the disk is short and never allowed
    /// to fail loudly (§16).
    private func snapshot(_ sessionID: UUID, body: String, reason: RevisionReason) async {
        guard snapshotsAllowed() else { return }
        do {
            try await revisions.addNoteRevision(
                NoteRevision(sessionID: sessionID, body: body, capturedAt: now(), reason: reason))
            lastSnapshotBody[sessionID] = body
        } catch {
            // Skipped, not surfaced: the note write is what matters and it reports for itself.
        }
    }

    /// The one write path. A failure is impossible to miss: it lands in `saveFailures` for the
    /// note's banner and the text stays in memory. Success clears it.
    private func write(_ session: Session) async {
        do {
            try await store.saveAll([session])
            lastError = nil
            saveFailures.removeValue(forKey: session.id)
            didWrite?()
        } catch {
            saveFailures[session.id] = DiskSpace.saveFailureMessage(for: error, subject: "This note")
            lastError = saveFailures[session.id]
        }
    }
}

/// The local-only tables the notes store needs beside `RecordStore`. `Database` provides
/// them; tests can substitute.
public protocol NoteRevisionStore: Sendable {
    func addNoteRevision(_ revision: NoteRevision) async throws
    func noteRevisions(for sessionID: UUID) async throws -> [NoteRevision]
    func conflictLosers(for recordID: UUID) async throws -> [ConflictLoser]
}

extension Database: NoteRevisionStore {}
