import Foundation
import StudyBotCore
import StudyBotKit

/// One realistic value of every persistable type, for store round-trip tests.
enum SampleRecords {
    static let now = Date(timeIntervalSince1970: 1_790_000_000.25)  // sub-second, on purpose

    static func sync(_ id: UUID = UUID()) -> SyncMetadata {
        var meta = SyncMetadata.new(id: id, at: now)
        meta.acknowledge(version: 3, seq: 4821)
        meta.baseVersion = 2
        meta.markEdited(at: now.addingTimeInterval(60))
        return meta
    }

    static let moduleID = Module.stableID(forCode: "COM1018DA")
    static let sessionID = UUID()
    static let deckID = UUID()
    static let assignmentID = UUID()

    static var module: Module {
        Module(
            sync: sync(moduleID), name: "Programming", code: "COM1018DA", colour: .indigo, year: 1,
            termNumber: 1, credits: 15, weighting: 12.5)
    }

    static var term: Term {
        Term(
            sync: sync(Term.stableID(year: 1, number: 1)), year: 1, number: 1,
            startDate: LocalDay(year: 2026, month: 9, day: 22).date,
            endDate: LocalDay(year: 2026, month: 12, day: 17).date)
    }

    static var assignment: Assignment {
        Assignment(
            sync: sync(assignmentID), title: "Programming coursework 1", moduleID: moduleID,
            status: .drafting,
            priority: .high, dueDate: LocalDay(year: 2026, month: 10, day: 15).date,
            briefText: "Write a thing",
            rubricText: "Criterion A", wordLimit: 2500, weighting: 40, draftText: "Once upon a time",
            draftSnapshots: [
                DraftSnapshot(text: "Once", capturedAt: now, wordCount: 1, source: .inApp, checkedByAI: true)
            ],
            grade: nil, targetGrade: 70, fieldOverrides: ["dueDate", "title"],
            subtasks: [Subtask(title: "Read the brief", isDone: true, order: 0, createdBy: .workBackPlan)],
            programmeEventID: ProgrammeEvent.stableID(forSourceUID: "uid"), ele2AssignmentID: "42")
    }

    static var session: Session {
        Session(
            sync: sync(sessionID), title: "Sets and relations", moduleID: moduleID, date: now,
            liveNotes: "- normalisation\nASK: does 3NF matter", transcript: "00:01 hello",
            structuredNotes: "## Normalisation", openQuestions: ["does 3NF matter"], markedAttended: true)
    }

    static var deck: Deck {
        Deck(sync: sync(deckID), title: "Week 1", sessionID: sessionID, moduleID: moduleID, lastStudied: now)
    }

    static var card: Card {
        Card(
            sync: sync(), deckID: deckID, front: "What is 3NF?", back: "No transitive dependencies",
            source: "line 3", box: 2, dueDate: LocalDay(year: 2026, month: 10, day: 1).date, lapses: 1)
    }

    static var quizAttempt: QuizAttempt {
        QuizAttempt(
            sync: sync(), deckID: deckID,
            questions: [
                QuizQuestion(prompt: "Q", options: ["a", "b"], correctIndex: 1, explanation: "because")
            ],
            answers: [1], score: 1, takenAt: now)
    }

    static var ksb: KSB {
        KSB(sync: sync(), code: "K3", category: .knowledge, text: "Official wording", markedStrong: true)
    }

    static var evidence: Evidence {
        Evidence(
            sync: sync(), title: "Sprint review", date: now, summary: "Led the review", ksbIDs: [UUID()],
            source: .workProject, assignmentID: assignmentID, reflection: "Went well")
    }

    static var otjEntry: OTJEntry {
        OTJEntry(
            sync: sync(), date: now, hours: 3, category: .workshop, description: "Monday workshop",
            sessionID: sessionID, isSubmittedToProvider: false)
    }

    static var proposal: Proposal {
        Proposal(
            sync: sync(), kind: .dateChange, source: .ele2, sourceRef: "moodle-42", title: "Move to 22 Oct",
            payload: Data([1, 2, 3]), targetID: assignmentID, state: .pending)
    }

    static var settings: Settings {
        var settings = Settings.defaults(at: now)
        settings.specialismChoices = ["COM3105DA"]
        settings.assignmentListScope = .all
        return settings
    }

    static var attachment: Attachment {
        Attachment(
            sync: sync(), filename: "brief.pdf", uti: "com.adobe.pdf", localPath: "/tmp/brief.pdf",
            sha256: "abc123", byteCount: 1024, extractedText: "The brief", sourceKind: .localFile,
            assignmentID: assignmentID)
    }

    static var aiRun: AIRun {
        AIRun(
            sync: sync(), capability: .checkDraft, promptSummary: "Checked draft against rubric",
            inputTokens: 1200, outputTokens: 300, model: "gpt-test", output: "Fine", acceptedByUser: true,
            timestamp: now, assignmentID: assignmentID)
    }

    static var programmeEvent: ProgrammeEvent {
        ProgrammeEvent(
            startDate: LocalDay(year: 2026, month: 9, day: 23).date,
            endDate: LocalDay(year: 2026, month: 9, day: 24).date, kind: .onCampus, title: "On-campus",
            moduleCodes: ["COM1018DA"], sourceUID: "uid", lastImportedAt: now)
    }
}
