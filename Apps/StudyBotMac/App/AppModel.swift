import AppKit
import Foundation
import Observation
import StudyBotCore
import StudyBotKit
import StudyBotUI

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
    private(set) var notes: NotesStore?
    private(set) var evidence: EvidenceStore?
    private(set) var hours: HoursStore?
    private(set) var revision: RevisionStore?
    /// Today's plan (§6.1), local to this Mac.
    private(set) var plan: PlanStore?
    private(set) var sync: SyncStore?
    private(set) var ai: AIStore?
    /// The ⌘K "Explain" answer, shown in a sheet while non-nil.
    var explanation: Explanation?
    /// Free space on the store's volume (§16 Reliability).
    private(set) var disk: DiskMonitor?
    private(set) var storeURL: URL?

    /// The session open in Modules & notes or Block mode.
    var selectedSlotID: UUID?
    /// The module expanded in Modules & notes.
    var selectedModuleID: UUID?
    /// Block mode (§6.6) when non-nil: the block being shown.
    var blockMode: CampusBlock?
    /// ⌘K.
    var paletteShown = false
    /// The evidence capture sheet, when a draft is being written (§6.5).
    var evidenceDraft: EvidenceStore.Draft?
    /// The one-line hours field (`L`).
    var hoursFieldShown = false
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
            storeURL = url
            let disk = DiskMonitor(storeURL: url)
            disk.start()
            self.disk = disk

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
            let notes = NotesStore(store: database, revisions: database, deviceID: deviceID, now: now)
            notes.snapshotsAllowed = { [weak disk] in disk?.snapshotsAllowed ?? true }
            await notes.load()
            self.notes = notes
            let evidence = EvidenceStore(store: database, deviceID: deviceID, now: now)
            await evidence.load()
            self.evidence = evidence
            let hours = HoursStore(store: database, deviceID: deviceID, now: now)
            await hours.load()
            self.hours = hours
            let revision = RevisionStore(store: database, deviceID: deviceID, now: now)
            await revision.load()
            self.revision = revision
            plan = PlanStore(persistence: UserDefaultsPlanPersistence(), now: now)

            let credentials = KeychainCredentialStore(account: KeychainCredentialStore.defaultAccount)
            let ai = AIStore(store: database, credentials: credentials, deviceID: deviceID, now: now)
            await ai.load()
            self.ai = ai
            let sync = SyncStore(database: database, credentials: credentials, deviceID: deviceID, now: now)
            store.didWrite = { [weak sync] in sync?.noteLocalWrite() }
            notes.didWrite = { [weak sync] in sync?.noteLocalWrite() }
            evidence.didWrite = { [weak sync] in sync?.noteLocalWrite() }
            hours.didWrite = { [weak sync] in sync?.noteLocalWrite() }
            revision.didWrite = { [weak sync] in sync?.noteLocalWrite() }
            self.sync = sync

            // §6.6: Block mode comes up by itself when today is inside an on-campus block.
            if !firstRun, let block = termCalendar?.block(containing: LocalDay(importedAt)) {
                blockMode = block
            }

            phase = firstRun ? .firstRun(firstRunFacts(store: store)) : .ready
            // Launch trigger (§3.4), off the critical path: the window never waits on the network.
            Task { [weak self] in
                await sync.start()
                await self?.assignments?.load()
                await self?.notes?.load()
                await self?.evidence?.load()
                await self?.hours?.load()
                await self?.revision?.load()
                self?.refreshPlan()
                await self?.refreshAI()
                self?.startAutomaticExports()
                #if DEBUG
                    await self?.pairFromEnvironmentIfRequested()
                    if let self { await DrillRunner.runIfRequested(model: self) }
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
            guard let url = env["STUDYBOT_PAIR_URL"], let code = env["STUDYBOT_PAIR_CODE"], let sync else {
                return
            }
            _ = await sync.pair(
                serverAddress: url, code: code, deviceName: env["STUDYBOT_PAIR_NAME"] ?? "Debug Mac")
            await assignments?.load()
        }
    #endif

    /// Re-reads the calendar the store holds, after a restore has replaced it.
    func reloadProgramme() async throws {
        events = try await database?.programmeEvents(includeCancelled: false) ?? []
        termCalendar = TermCalendar(events: events, derivedAt: now())
    }

    /// §16: the user must never quit over unsaved work believing it was saved.
    var hasUnsavedNotes: Bool { notes?.hasUnsavedNotes ?? false }

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

    /// `~/Library/Application Support/StudyBot/studybot.store`, created if needed. A Debug build
    /// honours `STUDYBOT_STORE_PATH` so the snapshot tour never touches the real store.
    static func storeURL() throws -> URL {
        #if DEBUG
            if let override = ProcessInfo.processInfo.environment["STUDYBOT_STORE_PATH"], !override.isEmpty {
                let url = URL(fileURLWithPath: override)
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                return url
            }
        #endif
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let folder = support.appendingPathComponent("StudyBot", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("studybot.store")
    }

    // MARK: Modules, sessions and Block mode

    /// The programme's sessions, one slot per event per day.
    var sessionSlots: [SessionSlot] { SessionCatalog.slots(in: events) }

    func slot(id: UUID) -> SessionSlot? { sessionSlots.first { $0.id == id } }

    /// Modules for a set of calendar codes, in programme order.
    func modules(forCodes codes: [String]) -> [Module] {
        (assignments?.modules ?? []).filter { codes.contains($0.code) }
    }

    /// The single module a session belongs to when the calendar names exactly one; nil when it
    /// names several, since a block day covers every module in the term.
    func moduleID(forCodes codes: [String]) -> UUID? {
        let matches = modules(forCodes: codes)
        return matches.count == 1 ? matches.first?.id : nil
    }

    /// Modules with sessions in the current term, for the Modules & notes list.
    var currentTermModules: [Module] {
        guard let store = assignments else { return [] }
        let current = store.currentTerm
        return store.modules.filter { module in
            guard !module.isArchived else { return false }
            guard let current else { return true }
            return module.termID == current.id || (module.spansYear && module.year == current.year)
        }
    }

    func openSession(_ slot: SessionSlot) {
        selection = .modules
        selectedSlotID = slot.id
    }

    /// Opens the session with this id, from Today's questions and recent notes.
    func openSession(id: UUID) {
        guard let slot = slot(id: id) else { return }
        blockMode = nil
        openSession(slot)
    }

    /// From Today's banner or the palette (§6.6).
    func enterBlockMode() {
        guard let calendar = termCalendar, let block = calendar.currentOrNextBlock(from: LocalDay(now()))
        else { return }
        blockMode = block
        if selectedSlotID == nil {
            let days = SessionCatalog.days(of: block, in: events)
            let today = LocalDay(now())
            selectedSlotID = (days.first { $0.day == today } ?? days.first)?.slots.first?.id
        }
    }

    func leaveBlockMode() {
        blockMode = nil
    }

    // MARK: Evidence (§6.5)

    func beginEvidence(source: EvidenceSource = .workProject, sessionID: UUID? = nil, title: String = "") {
        var draft = EvidenceStore.Draft(date: now(), source: source, sessionID: sessionID)
        draft.title = title
        evidenceDraft = draft
    }

    // MARK: AI (§7)

    /// What ⌘K asked and what came back.
    struct Explanation: Identifiable, Equatable {
        let id = UUID()
        let question: String
        var answer: String?
        var error: String?
    }

    /// The AI store follows the pairing: the server address comes from sync state.
    func refreshAI() async {
        guard let ai else { return }
        ai.configure(serverURL: sync?.state.serverURL)
        if ai.isAvailable {
            await ai.refreshBudget()
        }
    }

    /// ⌘K "Explain": uses the open session as context when there is one.
    func explain(_ question: String) async {
        guard let ai else { return }
        explanation = Explanation(question: question)
        let session = selectedSlotID.flatMap { notes?.session(id: $0) }
        let module = session.flatMap { s in assignments?.modules.first { $0.id == s.moduleID } }
        let answer = await ai.explain(question, session: session, module: module)
        explanation = Explanation(
            question: question, answer: answer, error: answer == nil ? ai.lastError : nil)
    }

    // MARK: Export state (§16); the methods are in AppModel+Export.

    /// The last export or restore outcome, for Settings → Data.
    var dataStatus: String?
    var lastExportURL: URL?
    /// When the weekly automatic export last ran (§16), for Settings → Data.
    var lastAutomaticExportAt: Date? =
        UserDefaults.standard.object(forKey: "studybot.lastAutomaticExport") as? Date
    {
        didSet { UserDefaults.standard.set(lastAutomaticExportAt, forKey: "studybot.lastAutomaticExport") }
    }
    var automaticExportStatus: String?
    var exportTimer: Task<Void, Never>?

    // MARK: ⌘K (§6.7)

    /// Navigation and actions only for now; AI and search wait for their milestones.
    var paletteCommands: [PaletteCommand] {
        var commands: [PaletteCommand] = [
            PaletteCommand(id: "action.evidence", section: .actions, title: "New evidence", detail: "⇧⌘E"),
            PaletteCommand(id: "action.assignment", section: .actions, title: "New assignment", detail: "⌘N"),
            PaletteCommand(id: "action.hours", section: .actions, title: "Log hours", detail: "L"),
            PaletteCommand(
                id: "action.block", section: .actions,
                title: blockMode == nil ? "Open Block mode" : "Leave Block mode", detail: "⇧⌘B"),
            PaletteCommand(id: "action.sync", section: .actions, title: "Sync now"),
            PaletteCommand(id: "action.settings", section: .actions, title: "Open Settings", detail: "⌘,"),
        ]
        for item in SidebarItem.allCases {
            commands.append(PaletteCommand(id: "go.\(item.rawValue)", section: .goTo, title: item.title))
        }
        for module in currentTermModules {
            commands.append(
                PaletteCommand(
                    id: "module.\(module.id)", section: .goTo, title: module.name, detail: module.code,
                    keywords: [module.code, module.shortCode]))
        }
        let today = LocalDay(now())
        for slot in sessionSlots
        where slot.day >= today.adding(days: -7) && slot.day <= today.adding(days: 60) {
            let when = RelativeDate.absolute(slot.day.date, relativeTo: now())
            commands.append(
                PaletteCommand(
                    id: "session.\(slot.id)", section: .goTo, title: "Session: \(slot.title)", detail: when,
                    keywords: [when] + slot.moduleCodes))
        }
        return commands
    }

    func perform(_ command: PaletteCommand) {
        paletteShown = false
        switch command.id {
        case "action.evidence": beginEvidence()
        case "action.assignment": Task { await createAssignment() }
        case "action.hours": showHoursField()
        case "action.block":
            if blockMode == nil { enterBlockMode() } else { leaveBlockMode() }
        case "action.sync": Task { await sync?.syncNow() }
        case "action.settings":
            NSApplication.shared.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        default:
            if command.id.hasPrefix("ai.explain:") {
                let question = String(command.id.dropFirst("ai.explain:".count))
                Task { await explain(question) }
            } else {
                performNavigation(command.id)
            }
        }
    }

    /// The "Ask AI" entry for whatever is typed (§6.7), when a server is paired.
    func explainCommand(for query: String) -> PaletteCommand? {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard ai?.isAvailable == true, trimmed.count >= 3 else { return nil }
        return PaletteCommand(
            id: "ai.explain:\(trimmed)", section: .askAI, title: "Explain \"\(trimmed)\"",
            detail: "costs tokens")
    }

    private func performNavigation(_ id: String) {
        if id.hasPrefix("go."), let item = SidebarItem(rawValue: String(id.dropFirst(3))) {
            blockMode = nil
            selection = item
        } else if id.hasPrefix("module."), let moduleID = UUID(uuidString: String(id.dropFirst(7))) {
            blockMode = nil
            selection = .modules
            selectedModuleID = moduleID
        } else if id.hasPrefix("session."), let slotID = UUID(uuidString: String(id.dropFirst(8))),
            let slot = slot(id: slotID)
        {
            blockMode = nil
            openSession(slot)
        }
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
