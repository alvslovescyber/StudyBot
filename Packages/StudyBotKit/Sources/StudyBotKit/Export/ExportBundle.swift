import Foundation
import StudyBotCore

/// One exported record: its sync metadata verbatim and every field, known or not, so a
/// restore reproduces the store exactly and a newer build's fields survive an older build's
/// export. Format documented in docs/export-format.md.
public struct ExportedRecord: Codable, Hashable, Sendable {
    public var type: String
    public var sync: SyncMetadata
    public var fields: [String: JSONValue]

    public init(type: String, sync: SyncMetadata, fields: [String: JSONValue]) {
        self.type = type
        self.sync = sync
        self.fields = fields
    }
}

/// `manifest.json`: what the bundle is and what it holds.
public struct ExportManifest: Codable, Hashable, Sendable {
    public static let currentFormatVersion = 1

    public var formatVersion: Int
    public var exportedAt: Date
    public var appVersion: String
    public var deviceID: String
    /// The sync cursor at export, so a restored store resumes where this one was.
    public var cursor: Int
    /// Record counts by type, plus `programmeEvents`, `noteRevisions`, `conflictLosers`, `notes`.
    public var counts: [String: Int]

    public init(
        formatVersion: Int = ExportManifest.currentFormatVersion, exportedAt: Date, appVersion: String,
        deviceID: String, cursor: Int, counts: [String: Int]
    ) {
        self.formatVersion = formatVersion
        self.exportedAt = exportedAt
        self.appVersion = appVersion
        self.deviceID = deviceID
        self.cursor = cursor
        self.counts = counts
    }
}

/// What a restore did.
public struct RestoreSummary: Hashable, Sendable {
    public var records: Int
    public var programmeEvents: Int
    public var noteRevisions: Int
    public var conflictLosers: Int
}

public enum ExportError: Error, Equatable, Sendable {
    case notAnExport(String)
    case unsupportedFormat(Int)

    public var message: String {
        switch self {
        case .notAnExport(let path): "\(path) is not a StudyBot export: no manifest.json."
        case .unsupportedFormat(let version):
            "This export is format \(version), which this build cannot read."
        }
    }
}

/// The client's own backup (§16 Data durability, After July 2029): a folder a text editor can
/// read in 2035. Records as JSON, notes as markdown, the programme calendar, every kept
/// revision and loser. Sync is not backup: this is the third copy.
public enum ExportBundle {
    public static let manifestName = "manifest.json"

    /// Writes a bundle into a new folder inside `parent` and returns its URL.
    @discardableResult
    public static func write(
        from database: Database, into parent: URL, appVersion: String, deviceID: String, now: Date = Date()
    ) async throws -> (url: URL, manifest: ExportManifest) {
        let folder = parent.appendingPathComponent(folderName(at: now), isDirectory: true)
        let files = FileManager.default
        try files.createDirectory(at: folder, withIntermediateDirectories: true)
        for sub in ["records", "notes", "programme", "attachments"] {
            try files.createDirectory(
                at: folder.appendingPathComponent(sub), withIntermediateDirectories: true)
        }

        var counts: [String: Int] = [:]
        let records = try await database.exportRecords()
        for (type, group) in Dictionary(grouping: records, by: \.type) {
            let sorted = group.sorted { $0.sync.id.uuidString < $1.sync.id.uuidString }
            try SyncCoding.encodePretty(sorted).write(
                to: folder.appendingPathComponent("records/\(type).json"))
            counts[type] = sorted.count
        }

        let events = try await database.programmeEvents(includeCancelled: true)
        try SyncCoding.encodePretty(events).write(to: folder.appendingPathComponent("programme/events.json"))
        counts["programmeEvents"] = events.count

        let revisions = try await database.allNoteRevisions()
        try SyncCoding.encodePretty(revisions).write(
            to: folder.appendingPathComponent("notes/revisions.json"))
        counts["noteRevisions"] = revisions.count
        let losers = try await database.allConflictLosers()
        try SyncCoding.encodePretty(losers).write(
            to: folder.appendingPathComponent("notes/conflict-losers.json"))
        counts["conflictLosers"] = losers.count

        let sessions = try await database.fetchAll(Session.self, includeDeleted: false).map(\.value)
        let modules = try await database.fetchAll(Module.self, includeDeleted: false).map(\.value)
        var notes = 0
        for session in sessions
        where session.hasNotes || session.transcript != nil || session.structuredNotes != nil {
            let name = markdownFileName(for: session)
            try markdown(for: session, modules: modules).write(
                to: folder.appendingPathComponent("notes/\(name)"), atomically: true, encoding: .utf8)
            notes += 1
        }
        counts["notes"] = notes

        let state = try await database.syncState()
        var exportedState = state
        exportedState.serverURL = state.serverURL
        try SyncCoding.encodePretty(exportedState).write(to: folder.appendingPathComponent("sync-state.json"))

        let manifest = ExportManifest(
            exportedAt: now, appVersion: appVersion, deviceID: deviceID, cursor: state.cursor, counts: counts)
        try SyncCoding.encodePretty(manifest).write(to: folder.appendingPathComponent(manifestName))
        try readme().write(to: folder.appendingPathComponent("README.txt"), atomically: true, encoding: .utf8)
        return (folder, manifest)
    }

    /// Reads a bundle back into `database`, record by record with its sync metadata intact.
    /// Existing rows with the same id are overwritten. The bearer token is not part of an export.
    public static func restore(from folder: URL, into database: Database) async throws -> RestoreSummary {
        let manifestURL = folder.appendingPathComponent(manifestName)
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            throw ExportError.notAnExport(folder.lastPathComponent)
        }
        let manifest = try SyncCoding.decode(ExportManifest.self, from: Data(contentsOf: manifestURL))
        guard manifest.formatVersion <= ExportManifest.currentFormatVersion else {
            throw ExportError.unsupportedFormat(manifest.formatVersion)
        }

        var summary = RestoreSummary(records: 0, programmeEvents: 0, noteRevisions: 0, conflictLosers: 0)
        let recordsFolder = folder.appendingPathComponent("records")
        let recordFiles =
            (try? FileManager.default.contentsOfDirectory(at: recordsFolder, includingPropertiesForKeys: nil))
            ?? []
        for file in recordFiles.sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
        where file.pathExtension == "json" {
            let records = try SyncCoding.decode([ExportedRecord].self, from: Data(contentsOf: file))
            summary.records += try await database.importRecords(records)
        }

        let eventsURL = folder.appendingPathComponent("programme/events.json")
        if let data = try? Data(contentsOf: eventsURL) {
            let events = try SyncCoding.decode([ProgrammeEvent].self, from: data)
            try await database.saveProgrammeEvents(events)
            summary.programmeEvents = events.count
        }
        if let data = try? Data(contentsOf: folder.appendingPathComponent("notes/revisions.json")) {
            let revisions = try SyncCoding.decode([NoteRevision].self, from: data)
            try await database.restoreNoteRevisions(revisions)
            summary.noteRevisions = revisions.count
        }
        if let data = try? Data(contentsOf: folder.appendingPathComponent("notes/conflict-losers.json")) {
            let losers = try SyncCoding.decode([ConflictLoser].self, from: data)
            try await database.restoreConflictLosers(losers)
            summary.conflictLosers = losers.count
        }
        if let data = try? Data(contentsOf: folder.appendingPathComponent("sync-state.json")) {
            var state = try SyncCoding.decode(SyncState.self, from: data)
            state.lastError = nil
            state.failingSince = nil
            try await database.saveSyncState(state)
        }
        return summary
    }

    // MARK: Markdown

    /// A note a text editor can read: title, date, modules, then the live notes as typed, the
    /// questions, the transcript and the structured notes when present.
    public static func markdown(for session: Session, modules: [Module]) -> String {
        var lines: [String] = ["# \(session.title)", ""]
        var meta = [RelativeDate.fullDate(session.date)]
        if let module = modules.first(where: { $0.id == session.moduleID }) {
            meta.append("\(module.code) \(module.name)")
        }
        lines.append(meta.joined(separator: " · "))
        lines.append("")
        lines.append("## Live notes")
        lines.append("")
        lines.append(
            session.liveNotes.isEmpty ? "(empty)" : session.liveNotes.trimmingCharacters(in: .newlines))
        if !session.openQuestions.isEmpty {
            lines += ["", "## Questions to ask", ""]
            lines += session.openQuestions.map { "- \($0)" }
        }
        if let transcript = session.transcript, !transcript.isEmpty {
            lines += ["", "## Transcript", "", transcript.trimmingCharacters(in: .newlines)]
        }
        if let structured = session.structuredNotes, !structured.isEmpty {
            lines += ["", "## Structured", "", structured.trimmingCharacters(in: .newlines)]
        }
        lines.append("")
        return lines.joined(separator: "\n")
    }

    /// "2026-09-28 Online lectures.md": sorts by date in any file browser.
    public static func markdownFileName(for session: Session) -> String {
        let day = LocalDay(session.date).isoString
        let safe = session.title.map { $0.isLetter || $0.isNumber || $0 == " " || $0 == "-" ? $0 : "-" }
        return "\(day) \(String(safe).trimmingCharacters(in: .whitespaces)).md"
    }

    /// "StudyBot export 2026-09-16 1105".
    static func folderName(at date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = UKCalendar.calendar
        formatter.locale = UKCalendar.locale
        formatter.timeZone = UKCalendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd HHmm"
        return "StudyBot export \(formatter.string(from: date))"
    }

    static func readme() -> String {
        """
        This folder is a complete export of StudyBot's data, made by the app itself.

        notes/            your session notes as Markdown, one file per session, readable anywhere
        records/          every record as JSON, one file per type, with its sync metadata
        programme/        the programme calendar as imported
        notes/revisions.json          earlier versions of notes kept while typing
        notes/conflict-losers.json    versions replaced by a sync from the other Mac
        manifest.json     what this export is and what it holds
        sync-state.json   where this Mac was in the sync (no credentials are included)

        Restore it from StudyBot → Settings → Data → Restore from an export. The format is
        documented in the repository under docs/export-format.md.
        """
    }
}

extension SyncCoding {
    /// Pretty-printed, sorted keys: the export is for people as much as for the app.
    public static func encodePretty<T: Encodable>(_ value: T) throws -> Data {
        let encoder = makeEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }
}
