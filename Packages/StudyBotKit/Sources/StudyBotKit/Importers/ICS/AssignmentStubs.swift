import Foundation
import StudyBotCore

/// The 30 backlog assignments the calendar creates (spec §4A: "A mandatory submission event
/// creates a matching Assignment in backlog status with the due date already set… Nobody
/// should ever type a deadline into this app by hand.")
///
/// What each submission actually is arrives from ELE2 later (§14, question 1). Until then the
/// stub carries only what the calendar knows: the due date, the originating event, and the
/// module when the event names exactly one. The real file names all three of a term's modules
/// on every submission, so the module is left unset and the title is the date.
public enum AssignmentStubs {
    /// One stub per non-cancelled submission event, in date order. Ids are derived from the
    /// event's UID so both Macs create the same record and the store can tell a stub it has
    /// already created from a new one.
    public static func stubs(for events: [ProgrammeEvent], modules: [Module], now: Date) -> [Assignment] {
        let modulesByCode = Dictionary(modules.map { ($0.code, $0) }, uniquingKeysWith: { first, _ in first })
        return
            events
            .filter { !$0.isCancelled && $0.kind == .assignment }
            .sorted { $0.startDate < $1.startDate }
            .map { event in
                let module = event.moduleCodes.count == 1 ? modulesByCode[event.moduleCodes[0]] : nil
                return Assignment(
                    sync: SyncMetadata.new(id: stableID(forEvent: event), at: now),
                    title: title(for: event, module: module),
                    moduleID: module?.id,
                    status: .backlog,
                    dueDate: event.startDate,
                    programmeEventID: event.id)
            }
    }

    /// The deterministic id of the stub for a submission event.
    public static func stableID(forEvent event: ProgrammeEvent) -> UUID {
        StableID.uuid(namespace: StableID.Namespace.assignmentStub, name: event.sourceUID)
    }

    /// "Programming" when the module is known, otherwise "Submission due 15 October 2026".
    static func title(for event: ProgrammeEvent, module: Module?) -> String {
        if let module {
            return module.name
        }
        return "Submission due \(RelativeDate.fullDate(event.startDate))"
    }
}
