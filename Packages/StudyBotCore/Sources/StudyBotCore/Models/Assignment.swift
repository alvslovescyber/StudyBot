import Foundation

/// A piece of assessed work (spec §4, §6.2). The 30 mandatory submissions are created from
/// the programme calendar in backlog status with the due date already set; nobody types a
/// deadline by hand (§4A).
///
/// Inverse relationships from the spec (`attachments`, `aiRuns`, `evidence`) are resolved
/// by lookup on those records' `assignmentID`. Subtasks and draft snapshots are owned and
/// stored inline.
public struct Assignment: Syncable {
    public static let recordType = "assignment"

    public var sync: SyncMetadata
    public var title: String
    public var moduleID: UUID?
    public var status: AssignmentStatus
    public var priority: Priority
    /// Date-only, at Europe/London midnight.
    public var dueDate: Date?
    /// Extracted from the PDF brief.
    public var briefText: String?
    /// Pasted by the user; drives the rubric checker. Until it exists the checker is disabled.
    public var rubricText: String?
    public var wordLimit: Int?
    /// Percentage of the module mark.
    public var weighting: Double?
    public var draftSource: DraftSource
    /// Current draft text, whatever its source.
    public var draftText: String?
    public var draftSnapshots: [DraftSnapshot]
    /// Actual mark once returned.
    public var grade: Double?
    /// Default 70.
    public var targetGrade: Double
    /// Fields edited by hand. ELE2 must not overwrite these (§6.2 "Who owns a field").
    public var fieldOverrides: Set<String>
    /// Tutor feedback, pasted in or pulled from the gradebook.
    public var feedback: String?
    public var subtasks: [Subtask]
    /// The mandatory-submission event this assignment was created from, if any. Not editable.
    public var programmeEventID: UUID?
    /// The term the due date falls in, so the Assignments list's current-term scope (§6.2) is
    /// a column filter. Maintained by whoever sets `dueDate`; nil when there is no due date or
    /// the date falls in a gap between terms.
    public var termID: UUID?
    /// The Moodle assignment id once ELE2 ingestion has matched it (§8.1). Seam only in v1.
    public var ele2AssignmentID: String?

    public init(
        sync: SyncMetadata,
        title: String,
        moduleID: UUID? = nil,
        status: AssignmentStatus = .backlog,
        priority: Priority = .none,
        dueDate: Date? = nil,
        briefText: String? = nil,
        rubricText: String? = nil,
        wordLimit: Int? = nil,
        weighting: Double? = nil,
        draftSource: DraftSource = .inApp,
        draftText: String? = nil,
        draftSnapshots: [DraftSnapshot] = [],
        grade: Double? = nil,
        targetGrade: Double = 70,
        fieldOverrides: Set<String> = [],
        feedback: String? = nil,
        subtasks: [Subtask] = [],
        programmeEventID: UUID? = nil,
        termID: UUID? = nil,
        ele2AssignmentID: String? = nil
    ) {
        self.sync = sync
        self.title = title
        self.moduleID = moduleID
        self.status = status
        self.priority = priority
        self.dueDate = dueDate
        self.briefText = briefText
        self.rubricText = rubricText
        self.wordLimit = wordLimit
        self.weighting = weighting
        self.draftSource = draftSource
        self.draftText = draftText
        self.draftSnapshots = draftSnapshots
        self.grade = grade
        self.targetGrade = targetGrade
        self.fieldOverrides = fieldOverrides
        self.feedback = feedback
        self.subtasks = subtasks
        self.programmeEventID = programmeEventID
        self.termID = termID
        self.ele2AssignmentID = ele2AssignmentID
    }

    /// Whether the assignment still needs work.
    public var isIncomplete: Bool { status.isIncomplete }

    /// Whether the assignment is still the untouched stub the calendar created (§9 shows
    /// these in italic grey until a real brief fills them in).
    public var isCalendarStub: Bool {
        programmeEventID != nil && briefText == nil && rubricText == nil && fieldOverrides.isEmpty
    }
}
