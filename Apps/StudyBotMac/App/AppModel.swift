import Foundation
import Observation
import StudyBotCore
import StudyBotKit

/// App-level state: which phase launch is in, what the sidebar shows, which assignment is
/// open. Constructed once at launch and injected through the environment (§3.3). Owns the
/// `Database` and the domain stores; views reach the stores through it.
@MainActor
@Observable
final class AppModel {
    /// What the window shows.
    enum Phase: Equatable {
        case loading
        /// First launch: the calendar has just been imported (§6.0).
        case firstRun(FirstRunFacts)
        case ready
        /// The store could not be opened. Says what happened and what fixes it.
        case failed(String)
    }

    /// The three real numbers on the first-run screen (§6.0).
    struct FirstRunFacts: Equatable {
        let submissionCount: Int
        let firstDeadline: Date?
        let daysToBlockOne: Int?
        let blockOne: CampusBlock?
    }

    private(set) var phase: Phase = .loading
    var selection: SidebarItem = .today
    var sidebarCollapsed: Bool = UserDefaults.standard.bool(forKey: "studybot.sidebarCollapsed") {
        didSet { UserDefaults.standard.set(sidebarCollapsed, forKey: "studybot.sidebarCollapsed") }
    }
    var selectedAssignmentID: UUID?

    private(set) var database: Database?
    private(set) var assignments: AssignmentStore?
    private(set) var sync: SyncStore?
    private(set) var termCalendar: TermCalendar?
    private(set) var events: [ProgrammeEvent] = []
    let editor = AssignmentEditor()
    let deviceID = DeviceIdentity.current()

    /// The clock. One place, so tests and previews can pin the day.
    var now: @Sendable () -> Date = { Date() }

    // MARK: Launch

    func start() async {
        guard phase == .loading else { return }
        do {
            let url = try AppModel.storeURL()
            let database = try Database.onDisk(at: url)
            self.database = database

            let firstRun = try await database.programmeEvents().isEmpty
            let importedAt = now()
            let summary = try await ProgrammeCalendarService(store: database).importBundledCalendar(
                now: importedAt)
            if !summary.issues.isEmpty {
                // Logged only: never user content, and the rest of the file imported (§3.10).
                print("StudyBot: \(summary.issues.count) calendar event(s) skipped on import")
            }

            events = try await database.programmeEvents(includeCancelled: false)
            termCalendar = TermCalendar(events: events, derivedAt: importedAt)

            let store = AssignmentStore(store: database, deviceID: deviceID, now: now)
            await store.load()
            assignments = store

            let sync = SyncStore(
                database: database, credentials: KeychainCredentialStore(), deviceID: deviceID, now: now)
            store.didWrite = { [weak sync] in sync?.noteLocalWrite() }
            self.sync = sync

            phase = firstRun ? .firstRun(firstRunFacts(store: store)) : .ready
            // Launch trigger (§3.4), off the critical path: the window never waits on the network.
            Task { [weak self] in
                await sync.start()
                await self?.assignments?.load()
                #if DEBUG
                    await self?.pairFromEnvironmentIfRequested()
                #endif
            }
        } catch {
            phase = .failed(
                "StudyBot couldn't open its data store. Check that ~/Library/Application Support is writable, then relaunch. (\(error.localizedDescription))"
            )
        }
    }

    #if DEBUG
        /// `STUDYBOT_PAIR_URL` and `STUDYBOT_PAIR_CODE` pair this build on launch, so the sandboxed
        /// app can be checked against a local server without typing into it. Debug only.
        private func pairFromEnvironmentIfRequested() async {
            let env = ProcessInfo.processInfo.environment
            guard let url = env["STUDYBOT_PAIR_URL"], let code = env["STUDYBOT_PAIR_CODE"], let sync,
                !sync.isPaired
            else { return }
            _ = await sync.pair(
                serverAddress: url, code: code, deviceName: env["STUDYBOT_PAIR_NAME"] ?? "Debug Mac")
            await assignments?.load()
        }
    #endif

    /// First run, screen one → Today.
    func continueFromFirstRun() {
        phase = .ready
        selection = .today
    }

    private func firstRunFacts(store: AssignmentStore) -> FirstRunFacts {
        let today = LocalDay(now())
        let deadlines = store.assignments.compactMap(\.dueDate).sorted()
        let block = termCalendar?.currentOrNextBlock(from: today)
        return FirstRunFacts(
            submissionCount: store.assignments.count,
            firstDeadline: deadlines.first,
            daysToBlockOne: termCalendar?.daysToNextBlock(from: today),
            blockOne: block)
    }

    /// `~/Library/Application Support/StudyBot/studybot.store`, created if needed.
    static func storeURL() throws -> URL {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let folder = support.appendingPathComponent("StudyBot", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("studybot.store")
    }

    // MARK: Assignments

    /// Opens an assignment in the detail panel. Leaving edit mode first if a different one opens.
    func open(_ assignment: Assignment) {
        if editor.isEditing, selectedAssignmentID != assignment.id {
            editor.discard()
        }
        selectedAssignmentID = assignment.id
    }

    func closeDetail() {
        editor.discard()
        selectedAssignmentID = nil
    }

    var selectedAssignment: Assignment? {
        guard let id = selectedAssignmentID else { return nil }
        return assignments?.assignment(id: id)
    }

    /// Menu and shortcut entry points (§10).
    func beginEditingSelected() {
        guard let assignment = selectedAssignment, !editor.isEditing else { return }
        editor.begin(assignment)
    }

    func saveEditing() async {
        guard let store = assignments else { return }
        await editor.save(using: store)
    }

    /// `⎋`: exits edit mode before closing the panel; a second press closes (§6.2).
    func escape() {
        if editor.isEditing {
            editor.requestCancel()
        } else if selectedAssignmentID != nil {
            closeDetail()
        }
    }

    func createAssignment() async {
        guard let store = assignments, let created = await store.createAssignment() else { return }
        selection = .assignments
        selectedAssignmentID = created.id
        editor.begin(created)
    }
}
