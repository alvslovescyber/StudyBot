import Foundation
import StudyBotCore

/// Imports a programme calendar into a store: events, terms, modules and the backlog
/// assignment stubs (§4A "Import behaviour"). Runs on first launch with the bundled ICS and
/// again from Settings when the university reissues the calendar. Idempotent: a second run
/// with the same file changes nothing.
///
/// Ownership rules on re-import:
/// - Events: merged by `sourceUID` (`ProgrammeCalendarImporter`). Removed ones are cancelled.
/// - Terms: calendar-derived, so re-derived and updated in place if their dates moved.
/// - Modules: inserted when new. Existing modules are the user's (renamed, recoloured,
///   archived) and are left alone.
/// - Assignments: one stub per submission event, inserted when missing. A stub whose due date
///   the calendar has moved is rescheduled **unless** the user has edited the date by hand
///   (`fieldOverrides` contains `"dueDate"`), per §6.2 "Who owns a field".
public struct ProgrammeCalendarService: Sendable {
    /// What one import did.
    public struct Summary: Sendable, Equatable {
        public var eventsAdded = 0
        public var eventsUpdated = 0
        public var eventsCancelled = 0
        public var eventsRestored = 0
        public var termsAdded = 0
        public var termsUpdated = 0
        public var modulesAdded = 0
        public var assignmentsAdded = 0
        public var assignmentsRescheduled = 0
        public var issues: [ICSProgrammeCalendarReader.Issue] = []

        /// Whether anything in the store changed.
        public var changedAnything: Bool {
            eventsAdded + eventsUpdated + eventsCancelled + eventsRestored + termsAdded + termsUpdated
                + modulesAdded + assignmentsAdded + assignmentsRescheduled > 0
        }
    }

    private let store: any RecordStore

    public init(store: any RecordStore) {
        self.store = store
    }

    /// Imports the calendar bundled in the app.
    public func importBundledCalendar(now: Date) async throws -> Summary {
        try await importCalendar(try BundledProgrammeCalendar.data(), now: now)
    }

    /// Imports an ICS file. Throws only if the file cannot be tokenized; a broken event
    /// becomes an issue in the summary and the rest still import.
    public func importCalendar(_ data: Data, now: Date) async throws -> Summary {
        let reading = try ICSProgrammeCalendarReader.read(data, importedAt: now)
        var summary = Summary(issues: reading.issues)

        // Events, then terms derived from them, then each event stamped with its term.
        let existing = try await store.programmeEvents(includeCancelled: true)
        let outcome = ProgrammeCalendarImporter.merge(existing: existing, incoming: reading.events, now: now)
        let calendar = TermCalendar(events: outcome.events, derivedAt: now)
        let events = outcome.events.map { event in
            var stamped = event
            stamped.termID = calendar.term(containing: LocalDay(event.startDate))?.id
            return stamped
        }
        try await store.saveProgrammeEvents(events)
        summary.eventsAdded = outcome.added.count
        summary.eventsUpdated = outcome.updated.count
        summary.eventsCancelled = outcome.cancelled.count
        summary.eventsRestored = outcome.restored.count

        // Terms
        let storedTerms = Dictionary(
            uniqueKeysWithValues: try await store.fetchAll(Term.self, includeDeleted: true).map {
                ($0.id, $0.value)
            })
        var termsToSave: [Term] = []
        for derived in calendar.terms {
            if var current = storedTerms[derived.id] {
                if current.startDate != derived.startDate || current.endDate != derived.endDate {
                    current.startDate = derived.startDate
                    current.endDate = derived.endDate
                    current.sync.markEdited(at: now)
                    termsToSave.append(current)
                    summary.termsUpdated += 1
                }
            } else {
                termsToSave.append(derived)
                summary.termsAdded += 1
            }
        }
        try await store.saveAll(termsToSave)

        // Modules
        let storedModules = try await store.fetchAll(Module.self, includeDeleted: true).map(\.value)
        let storedModuleIDs = Set(storedModules.map(\.id))
        let newModules = ModuleSeeder.modules(from: reading, terms: calendar, now: now)
            .filter { !storedModuleIDs.contains($0.id) }
        try await store.saveAll(newModules)
        summary.modulesAdded = newModules.count
        let allModules = storedModules + newModules

        // Assignment stubs
        let storedAssignments = try await store.fetchAll(Assignment.self, includeDeleted: true).map(\.value)
        var byEvent: [UUID: Assignment] = [:]
        for assignment in storedAssignments {
            if let eventID = assignment.programmeEventID, byEvent[eventID] == nil {
                byEvent[eventID] = assignment
            }
        }
        var assignmentsToSave: [Assignment] = []
        for var stub in AssignmentStubs.stubs(for: events, modules: allModules, now: now) {
            guard let eventID = stub.programmeEventID else { continue }
            stub.termID = stub.dueDate.flatMap { calendar.term(containing: LocalDay($0))?.id }
            if var current = byEvent[eventID] {
                let moved = current.dueDate.map { LocalDay($0) } != stub.dueDate.map { LocalDay($0) }
                if moved, !current.fieldOverrides.contains("dueDate") {
                    current.dueDate = stub.dueDate
                    current.termID = stub.termID
                    current.sync.markEdited(at: now)
                    assignmentsToSave.append(current)
                    summary.assignmentsRescheduled += 1
                }
            } else {
                assignmentsToSave.append(stub)
                summary.assignmentsAdded += 1
            }
        }
        try await store.saveAll(assignmentsToSave)

        return summary
    }
}
