import Foundation
import StudyBotCore

/// Where sessions come from (§6.3, §6.6): the programme calendar. Every teaching event yields
/// one slot per day it covers, so a two-day on-campus event is two sessions with two sets of
/// notes. A slot's id is stable across Macs, so opening the same session on both offline
/// creates one record, not two.
public struct SessionSlot: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let eventID: UUID
    public let eventSourceUID: String
    public let day: LocalDay
    public let kind: EventKind
    public let title: String
    public let moduleCodes: [String]

    /// The session record for this slot, if none exists yet.
    public func newSession(moduleID: UUID?, at now: Date, deviceID: String) -> Session {
        Session(
            sync: .new(id: id, at: now, deviceID: deviceID), title: title, moduleID: moduleID,
            programmeEventID: eventID, date: day.date)
    }
}

/// One day of an on-campus block with its sessions (§6.6 "a column per day").
public struct BlockDay: Identifiable, Hashable, Sendable {
    public var id: LocalDay { day }
    public let day: LocalDay
    public let slots: [SessionSlot]
}

public enum SessionCatalog {
    /// Every session slot in the calendar, in date order. Cancelled events yield none.
    public static func slots(in events: [ProgrammeEvent]) -> [SessionSlot] {
        events
            .filter { !$0.isCancelled && $0.kind.isSession }
            .flatMap { event in
                (LocalDay(event.startDate)...LocalDay(event.endDate)).days.map { day in
                    SessionSlot(
                        id: Session.stableID(eventSourceUID: event.sourceUID, dayISO: day.isoString),
                        eventID: event.id, eventSourceUID: event.sourceUID, day: day, kind: event.kind,
                        title: title(for: event, on: day), moduleCodes: event.moduleCodes)
                }
            }
            .sorted { ($0.day, $0.title) < ($1.day, $1.title) }
    }

    /// Slots for one module's code, in date order.
    public static func slots(in events: [ProgrammeEvent], moduleCode: String) -> [SessionSlot] {
        slots(in: events).filter { $0.moduleCodes.contains(moduleCode) }
    }

    /// The days of a block, each with that day's sessions. Two or three days; never assumed.
    public static func days(of block: CampusBlock, in events: [ProgrammeEvent]) -> [BlockDay] {
        let all = slots(in: events)
        return (block.start...block.end).days.map { day in
            BlockDay(day: day, slots: all.filter { $0.day == day })
        }
    }

    /// The slot for a day's online session, if there is one (§6.6 "Monday session mode").
    public static func slot(on day: LocalDay, in events: [ProgrammeEvent]) -> SessionSlot? {
        slots(in: events).first { $0.day == day }
    }

    /// "Induction", "On campus, day 2", "Online lectures". The calendar's own title, made
    /// per-day where an event spans days.
    static func title(for event: ProgrammeEvent, on day: LocalDay) -> String {
        switch event.kind {
        case .induction: return "Induction"
        case .onCampus:
            let index = LocalDay(event.startDate).days(until: day) + 1
            return event.isMultiDay ? "On campus, day \(index)" : "On campus"
        default:
            return event.title
        }
    }
}
