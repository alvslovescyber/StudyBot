import Foundation
import StudyBotCore

/// Turns a parsed programme calendar into `ProgrammeEvent`s (spec §4A).
///
/// The rules that matter, all of which the real file exercises:
/// - `kind` comes from the `CATEGORIES` line ("DTS L6 Assignment" → `.assignment`), with the
///   `SUMMARY` wording as a fallback.
/// - All-day `DTEND` is **exclusive**, so it is pulled back one day: a `DTSTART:20260923 /
///   DTEND:20260925` event is 23–24 September. A missing `DTEND` means a one-day event.
/// - Module codes are matched by pattern (`COM1018DA`) anywhere in the description, which
///   copes with the year-3 "Specialism 1 module (out of COM3105DA, …)" wording.
/// - The title is the `SUMMARY` with the "DTS L6: " prefix removed.
public enum ICSProgrammeCalendarReader {
    /// Why one `VEVENT` was skipped. The rest of the file still imports.
    public struct Issue: Error, Hashable, Sendable, CustomStringConvertible {
        public enum Reason: Hashable, Sendable {
            case missingUID
            case missingStart
            case unparseableDate(String)
            case endBeforeStart
            case unknownKind(categories: String?, summary: String?)
        }

        public let uid: String?
        public let reason: Reason

        public var description: String { "\(uid ?? "<no uid>"): \(reason)" }
    }

    /// The outcome of reading one file: the events it describes and anything that could not be read.
    public struct Reading: Sendable {
        public var events: [ProgrammeEvent]
        public var issues: [Issue]
    }

    /// Reads every `VEVENT` in `data`, stamping each event as imported at `now`.
    public static func read(_ data: Data, importedAt now: Date) throws(ICSParser.Error) -> Reading {
        let calendar = try ICSParser.parse(data)
        return read(calendar, importedAt: now)
    }

    /// Reads every `VEVENT` in an already-parsed calendar.
    public static func read(_ calendar: ICSComponent, importedAt now: Date) -> Reading {
        var events: [ProgrammeEvent] = []
        var issues: [Issue] = []
        for component in calendar.events {
            switch event(from: component, importedAt: now) {
            case .success(let event): events.append(event)
            case .failure(let issue): issues.append(issue)
            }
        }
        events.sort {
            ($0.startDate, $0.kind.rawValue, $0.sourceUID) < ($1.startDate, $1.kind.rawValue, $1.sourceUID)
        }
        return Reading(events: events, issues: issues)
    }

    static func event(from component: ICSComponent, importedAt now: Date) -> Result<ProgrammeEvent, Issue> {
        let uid = component.property("UID")?.value.trimmingCharacters(in: .whitespaces)
        guard let uid, !uid.isEmpty else {
            return .failure(Issue(uid: nil, reason: .missingUID))
        }
        guard let startText = component.property("DTSTART")?.value else {
            return .failure(Issue(uid: uid, reason: .missingStart))
        }
        guard let start = LocalDay(iso: dateOnly(startText)) else {
            return .failure(Issue(uid: uid, reason: .unparseableDate(startText)))
        }

        let end: LocalDay
        if let endText = component.property("DTEND")?.value {
            guard let exclusiveEnd = LocalDay(iso: dateOnly(endText)) else {
                return .failure(Issue(uid: uid, reason: .unparseableDate(endText)))
            }
            // RFC 5545: DTEND on a date-valued event is the day *after* the last day.
            end = exclusiveEnd.adding(days: -1)
        } else {
            end = start
        }
        guard end >= start else {
            return .failure(Issue(uid: uid, reason: .endBeforeStart))
        }

        let categories = component.property("CATEGORIES")?.textValue
        let summary = component.property("SUMMARY")?.textValue
        guard let kind = kind(categories: categories, summary: summary) else {
            return .failure(Issue(uid: uid, reason: .unknownKind(categories: categories, summary: summary)))
        }

        let description = component.property("DESCRIPTION")?.textValue ?? ""
        return .success(
            ProgrammeEvent(
                startDate: start.date,
                endDate: end.date,
                kind: kind,
                title: title(from: summary),
                moduleCodes: moduleCodes(in: description),
                sourceUID: uid,
                lastImportedAt: now))
    }

    /// Strips any time part from a DATE-TIME value so `20260923T090000Z` still reads as a day.
    private static func dateOnly(_ value: String) -> String {
        if let tIndex = value.firstIndex(of: "T") {
            return String(value[..<tIndex])
        }
        return value
    }

    /// The `EventKind` for a CATEGORIES value such as "DTS L6 On-campus", falling back to
    /// keywords in the SUMMARY.
    static func kind(categories: String?, summary: String?) -> EventKind? {
        if let categories, let kind = kind(fromLabel: categories) {
            return kind
        }
        if let summary, let kind = kind(fromLabel: summary) {
            return kind
        }
        return nil
    }

    private static func kind(fromLabel label: String) -> EventKind? {
        let normalised = label.lowercased().filter(\.isLetter)
        // Order matters where one label contains another ("online" appears nowhere else, but
        // "assignment" and "epa" are checked before generic words).
        if normalised.contains("bankholiday") { return .bankHoliday }
        if normalised.contains("closure") { return .closure }
        if normalised.contains("readingweek") { return .readingWeek }
        if normalised.contains("induction") { return .induction }
        if normalised.contains("oncampus") { return .onCampus }
        if normalised.contains("online") { return .online }
        if normalised.contains("assignment") || normalised.contains("submission") { return .assignment }
        if normalised.contains("gateway") { return .gateway }
        if normalised.contains("endpointassessment") || normalised.hasSuffix("epa")
            || normalised.contains("epawindow")
        {
            return .epa
        }
        return nil
    }

    /// "DTS L6: Online lectures" → "Online lectures". Untitled events get their kind as a title.
    static func title(from summary: String?) -> String {
        guard let summary else { return "" }
        var title = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = "DTS L6:"
        if title.uppercased().hasPrefix(prefix) {
            title = String(title.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
        }
        return title
    }

    /// Every Exeter module code in `text`, in order of first appearance, without duplicates.
    static func moduleCodes(in text: String) -> [String] {
        var seen = Set<String>()
        var codes: [String] = []
        for match in text.matches(of: /COM\d{4}DA/) {
            let code = String(match.output)
            if seen.insert(code).inserted {
                codes.append(code)
            }
        }
        return codes
    }

    /// "Modules in this block: COM1018DA Programming / COM1014DA Discrete …" → the module
    /// names keyed by code, for seeding `Module` records. Only modules with a name after the
    /// code are returned; bare codes inside the year-3 specialism list are not.
    static func moduleNames(in description: String) -> [String: String] {
        var names: [String: String] = [:]
        guard let range = description.range(of: "Modules in this block:") else { return names }
        var section = String(description[range.upperBound...])
        if let end = section.range(of: "\n\n") {
            section = String(section[..<end.lowerBound])
        }
        for part in section.split(separator: "/") {
            let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let match = trimmed.firstMatch(of: /^(COM\d{4}DA)\s+(.+)$/) else { continue }
            let name = String(match.output.2).trimmingCharacters(in: .whitespacesAndNewlines)
            let code = String(match.output.1)
            if !name.isEmpty, names[code] == nil {
                names[code] = name
            }
        }
        return names
    }
}
