import Foundation
import StudyBotCore

/// Idempotent merge of a freshly read calendar into the events already stored (spec §4A
/// "Import behaviour"). Matched on `sourceUID`: changed dates update in place, new events
/// are added, and events missing from the new file are **marked cancelled rather than
/// deleted**, so any notes attached to them survive.
///
/// Pure: takes the existing events and the new reading, returns the merged set and a summary.
/// The store persists the result; nothing here touches a database.
public enum ProgrammeCalendarImporter {
    /// What one import did.
    public struct Outcome: Sendable {
        /// The full merged event set, sorted by start date.
        public var events: [ProgrammeEvent]
        public var added: [UUID]
        public var updated: [UUID]
        public var cancelled: [UUID]
        /// Events that reappeared in the file after having been cancelled.
        public var restored: [UUID]
        public var unchangedCount: Int
        public var issues: [ICSProgrammeCalendarReader.Issue]

        /// Whether the import changed anything at all.
        public var changedAnything: Bool {
            !(added.isEmpty && updated.isEmpty && cancelled.isEmpty && restored.isEmpty)
        }
    }

    /// Reads `data` and merges it into `existing`.
    public static func importCalendar(
        _ data: Data, into existing: [ProgrammeEvent], now: Date
    ) throws(ICSParser.Error) -> Outcome {
        let reading = try ICSProgrammeCalendarReader.read(data, importedAt: now)
        var outcome = merge(existing: existing, incoming: reading.events, now: now)
        outcome.issues = reading.issues
        return outcome
    }

    /// Merges `incoming` (a complete reading of one file) into `existing`.
    public static func merge(existing: [ProgrammeEvent], incoming: [ProgrammeEvent], now: Date) -> Outcome {
        var byUID: [String: ProgrammeEvent] = [:]
        for event in existing {
            byUID[event.sourceUID] = event
        }

        var outcome = Outcome(
            events: [], added: [], updated: [], cancelled: [], restored: [], unchangedCount: 0, issues: [])
        var seen = Set<String>()

        for fresh in incoming {
            seen.insert(fresh.sourceUID)
            guard var current = byUID[fresh.sourceUID] else {
                byUID[fresh.sourceUID] = fresh
                outcome.added.append(fresh.id)
                continue
            }

            let wasCancelled = current.isCancelled
            let differs =
                current.startDate != fresh.startDate || current.endDate != fresh.endDate
                || current.kind != fresh.kind || current.title != fresh.title
                || current.moduleCodes != fresh.moduleCodes

            // Update in place, keeping the id so attached sessions and assignments still point here.
            current.startDate = fresh.startDate
            current.endDate = fresh.endDate
            current.kind = fresh.kind
            current.title = fresh.title
            current.moduleCodes = fresh.moduleCodes
            current.cancelledAt = nil
            current.lastImportedAt = now
            byUID[fresh.sourceUID] = current

            if wasCancelled {
                outcome.restored.append(current.id)
            } else if differs {
                outcome.updated.append(current.id)
            } else {
                outcome.unchangedCount += 1
            }
        }

        for (uid, event) in byUID where !seen.contains(uid) {
            guard !event.isCancelled else {
                outcome.unchangedCount += 1
                continue
            }
            var cancelled = event
            cancelled.cancelledAt = now
            byUID[uid] = cancelled
            outcome.cancelled.append(cancelled.id)
        }

        outcome.events = byUID.values.sorted {
            ($0.startDate, $0.kind.rawValue, $0.sourceUID) < ($1.startDate, $1.kind.rawValue, $1.sourceUID)
        }
        return outcome
    }
}
