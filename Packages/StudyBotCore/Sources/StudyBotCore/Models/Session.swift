import Foundation

/// A single teaching event's notes (spec §4). The UI word is "session" because most are
/// workshops. Three text fields, deliberately separate: `liveNotes` is never overwritten by
/// AI; structuring writes a new field so the user's own words survive.
///
/// `attachments` and `decks` from the spec are inverses resolved by lookup on `sessionID`.
public struct Session: Syncable {
    public static let recordType = "session"

    public var sync: SyncMetadata
    public var title: String
    public var moduleID: UUID?
    /// The programme event this session belongs to: a Monday online session or a day of an
    /// on-campus block. Covers the spec's `block: Block?`.
    public var programmeEventID: UUID?
    public var date: Date
    /// Typed during the session, raw and messy. Never touched by AI.
    public var liveNotes: String
    /// Pasted or imported.
    public var transcript: String?
    /// AI output, markdown.
    public var structuredNotes: String?
    /// Things to ask the tutor, captured live from `ASK:` lines.
    public var openQuestions: [String]
    /// The user explicitly marked the session attended (§4 "What counts as attended").
    public var markedAttended: Bool

    public init(
        sync: SyncMetadata,
        title: String,
        moduleID: UUID? = nil,
        programmeEventID: UUID? = nil,
        date: Date,
        liveNotes: String = "",
        transcript: String? = nil,
        structuredNotes: String? = nil,
        openQuestions: [String] = [],
        markedAttended: Bool = false
    ) {
        self.sync = sync
        self.title = title
        self.moduleID = moduleID
        self.programmeEventID = programmeEventID
        self.date = date
        self.liveNotes = liveNotes
        self.transcript = transcript
        self.structuredNotes = structuredNotes
        self.openQuestions = openQuestions
        self.markedAttended = markedAttended
    }

    /// Whether the notes have any content at all.
    public var hasNotes: Bool {
        !liveNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
