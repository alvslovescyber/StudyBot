import Foundation
import Observation
import StudyBotCore

/// The Assignments domain store (spec §3.3): the one `@Observable` object the Assignments
/// screen reads from. Views never fetch, never format a date, never decide what "overdue"
/// or "current term" means; they read these properties and call the intent methods.
@MainActor
@Observable
public final class AssignmentStore {
    /// A status group as the list shows it.
    public struct Group: Identifiable, Sendable {
        public let status: AssignmentStatus
        public let assignments: [Assignment]
        public var id: AssignmentStatus { status }
    }

    /// The order groups appear in (§6.2): work in progress first, the archive last.
    public static let groupOrder: [AssignmentStatus] = [
        .drafting, .review, .todo, .backlog, .submitted, .graded,
    ]

    public private(set) var assignments: [Assignment] = []
    public private(set) var modules: [Module] = []
    public private(set) var terms: [Term] = []
    public private(set) var settings: Settings
    public private(set) var lastError: String?

    /// Which module the list is filtered to. Nil is "All modules".
    public var moduleFilter: UUID?

    /// Called after every successful local write, so the sync engine can run once the edits
    /// settle (§3.4 "after any local write settles for 10 seconds").
    public var didWrite: (@MainActor () -> Void)?

    private let store: any RecordStore
    private let deviceID: String
    private let now: @Sendable () -> Date

    public init(store: any RecordStore, deviceID: String, now: @escaping @Sendable () -> Date = { Date() }) {
        self.store = store
        self.deviceID = deviceID
        self.now = now
        self.settings = Settings.defaults(at: now())
    }

    // MARK: Loading

    /// Reads everything the screen needs. Cheap enough to call after every save.
    public func load() async {
        do {
            assignments = try await store.fetchAll(Assignment.self, includeDeleted: false).map(\.value)
            modules = try await store.fetchAll(Module.self, includeDeleted: false).map(\.value)
            terms = try await store.fetchAll(Term.self, includeDeleted: false).map(\.value)
                .sorted { $0.startDate < $1.startDate }
            if let stored = try await store.fetchAll(Settings.self, includeDeleted: false).first?.value {
                settings = stored
            }
            lastError = nil
        } catch {
            lastError = "Couldn't read the store: \(error.localizedDescription)"
        }
    }

    // MARK: Scope (§6.2)

    /// The list scope: current term by default, persisted in Settings.
    public var scope: AssignmentListScope {
        get { settings.assignmentListScope }
        set {
            guard settings.assignmentListScope != newValue else { return }
            settings.assignmentListScope = newValue
            settings.sync.markEdited(at: now(), by: deviceID)
            let snapshot = settings
            Task {
                try? await store.saveAll([snapshot])
                didWrite?()
            }
        }
    }

    /// The term "now" refers to: the one containing today, or, before a term starts (the
    /// September before induction, the gaps between terms), the next one. On 14 September 2026
    /// that is year 1 term 1, so the three term-1 stubs show.
    public var currentTerm: Term? {
        let today = LocalDay(now())
        return terms.first { LocalDay($0.startDate) <= today && today <= LocalDay($0.endDate) }
            ?? terms.first { LocalDay($0.startDate) > today }
            ?? terms.last
    }

    /// Assignments in scope, module filter applied. An assignment with no due date has no term
    /// and stays visible in every scope so nothing the user creates can vanish.
    public var visible: [Assignment] {
        assignments
            .filter(inScope)
            .filter { moduleFilter == nil || $0.moduleID == moduleFilter }
            .sorted(by: AssignmentStore.byDueDate)
    }

    /// How many live assignments the scope hides. Drives "N more submissions in later terms".
    public var hiddenCount: Int {
        assignments.count - assignments.filter(inScope).count
    }

    /// Whether every hidden assignment falls after the current scope, so "later terms" is true.
    public var hiddenAreAllLater: Bool {
        let scopeEnd = scopeEndDate
        return assignments.filter { !inScope($0) }.allSatisfy { assignment in
            guard let due = assignment.dueDate, let scopeEnd else { return false }
            return due > scopeEnd
        }
    }

    /// Visible assignments grouped by status in `groupOrder`, empty groups omitted.
    public var groups: [Group] {
        let visible = visible
        return AssignmentStore.groupOrder.compactMap { status in
            let members = visible.filter { $0.status == status }
            return members.isEmpty ? nil : Group(status: status, assignments: members)
        }
    }

    private func inScope(_ assignment: Assignment) -> Bool {
        guard assignment.dueDate != nil else { return true }
        switch scope {
        case .all:
            return true
        case .currentTerm:
            return assignment.termID == currentTerm?.id
        case .currentYear:
            guard let year = currentTerm?.year else { return true }
            let yearTermIDs = Set(terms.filter { $0.year == year }.map(\.id))
            return assignment.termID.map(yearTermIDs.contains) ?? false
        }
    }

    private var scopeEndDate: Date? {
        switch scope {
        case .all: return nil
        case .currentTerm: return currentTerm?.endDate
        case .currentYear:
            guard let year = currentTerm?.year else { return nil }
            return terms.filter { $0.year == year }.map(\.endDate).max()
        }
    }

    private static func byDueDate(_ lhs: Assignment, _ rhs: Assignment) -> Bool {
        switch (lhs.dueDate, rhs.dueDate) {
        case (let left?, let right?) where left != right: return left < right
        case (nil, .some): return false
        case (.some, nil): return true
        default: return lhs.title < rhs.title
        }
    }

    // MARK: Lookups

    public func module(for assignment: Assignment) -> Module? {
        assignment.moduleID.flatMap { id in modules.first { $0.id == id } }
    }

    public func assignment(id: UUID) -> Assignment? {
        assignments.first { $0.id == id }
    }

    /// Modules a user can assign work to: not archived, in year order then programme order.
    public var assignableModules: [Module] {
        modules.filter { !$0.isArchived }
    }

    // MARK: Intents

    /// Saves an edited assignment (§6.2 "Save is explicit"). `changedFields` are the fields the
    /// user touched; each joins `fieldOverrides` so ELE2 can never overwrite them (§6.2 "Who
    /// owns a field"). Bumps `updatedAt`, marks dirty, recomputes the term from the due date,
    /// writes once, then reloads.
    public func save(_ edited: Assignment, changedFields: Set<String>) async {
        var record = edited
        record.fieldOverrides.formUnion(changedFields)
        record.termID = termID(for: record.dueDate)
        record.sync.markEdited(at: now(), by: deviceID)
        do {
            try record.validate()
            try await store.saveAll([record])
            await load()
            didWrite?()
        } catch let error as ValidationError {
            lastError = error.issues.map(\.message).joined(separator: ". ")
        } catch {
            lastError = DiskSpace.saveFailureMessage(for: error, subject: "This assignment")
        }
    }

    /// One field changed from a row's hover actions (§6.2 hover reveals status, priority and
    /// due date). The same write as a save of one field: it joins `fieldOverrides`, so ELE2
    /// never overwrites what was set by hand.
    public func set(_ id: UUID, status: AssignmentStatus) async {
        guard var record = assignment(id: id), record.status != status else { return }
        record.status = status
        await save(record, changedFields: ["status"])
    }

    public func set(_ id: UUID, priority: Priority) async {
        guard var record = assignment(id: id), record.priority != priority else { return }
        record.priority = priority
        await save(record, changedFields: ["priority"])
    }

    public func set(_ id: UUID, dueDate: Date?) async {
        guard var record = assignment(id: id) else { return }
        let day = dueDate.map(UKCalendar.startOfDay)
        guard record.dueDate.map(LocalDay.init) != day.map(LocalDay.init) else { return }
        record.dueDate = day
        await save(record, changedFields: ["dueDate"])
    }

    /// Creates a new, untitled assignment in backlog and returns it for the detail panel to
    /// open in edit mode.
    public func createAssignment() async -> Assignment? {
        let assignment = Assignment(
            sync: .new(at: now(), deviceID: deviceID), title: "New assignment", status: .backlog)
        do {
            try await store.saveAll([assignment])
            await load()
            didWrite?()
            return assignment
        } catch {
            lastError = "Couldn't create the assignment: \(error.localizedDescription)"
            return nil
        }
    }

    /// Tombstones an assignment (§3.4: deletions are tombstones). The row stays for sync.
    public func delete(_ id: UUID) async {
        guard var record = assignment(id: id) else { return }
        record.sync.markDeleted(at: now(), by: deviceID)
        do {
            try await store.saveAll([record])
            await load()
            didWrite?()
        } catch {
            lastError = "Couldn't delete: \(error.localizedDescription)"
        }
    }

    /// The term a due date falls in, by the loaded terms. Nil for no date or a gap.
    public func termID(for dueDate: Date?) -> UUID? {
        guard let dueDate else { return nil }
        let day = LocalDay(dueDate)
        return terms.first { LocalDay($0.startDate) <= day && day <= LocalDay($0.endDate) }?.id
    }
}
