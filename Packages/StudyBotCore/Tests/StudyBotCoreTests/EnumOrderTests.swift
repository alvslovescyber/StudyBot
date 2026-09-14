import StudyBotCore
import Testing

/// §0: "Do not invent these — the supporting types and enum orders (§4)." These tests pin
/// every case list to the spec's order and raw value, so a reordering shows up as a
/// failing test rather than a subtly different list in the UI or on the wire.
@Suite("Enum orders and raw values match §4")
struct EnumOrderTests {
    @Test("AssignmentStatus mirrors Linear's state order")
    func assignmentStatus() {
        #expect(
            AssignmentStatus.allCases.map(\.rawValue) == [
                "backlog", "todo", "drafting", "review", "submitted", "graded",
            ])
        #expect(AssignmentStatus.allCases.filter(\.isIncomplete).count == 4)
    }

    @Test("Priority ascends none → urgent with 0–4 bars")
    func priority() {
        #expect(Priority.allCases.map(\.rawValue) == ["none", "low", "medium", "high", "urgent"])
        #expect(Priority.allCases.map(\.barCount) == [0, 1, 2, 3, 4])
        #expect(Priority.none < Priority.urgent)
    }

    @Test("OTJCategory uses the Supporting types list, including workshop")
    func otjCategory() {
        #expect(
            OTJCategory.allCases.map(\.rawValue) == [
                "lecture", "workshop", "selfStudy", "mentoring", "shadowing",
                "projectWork", "research", "writingUp", "training",
            ])
    }

    @Test("EventKind order and working-day rules")
    func eventKind() {
        #expect(
            EventKind.allCases.map(\.rawValue) == [
                "induction", "onCampus", "online", "assignment", "readingWeek",
                "closure", "bankHoliday", "gateway", "epa",
            ])
        #expect(
            EventKind.allCases.filter(\.blocksWorkingDay) == [.induction, .onCampus, .closure, .bankHoliday])
        #expect(EventKind.allCases.filter(\.isCampusDay) == [.induction, .onCampus])
        #expect(!EventKind.readingWeek.blocksWorkingDay)
        #expect(EventKind.allCases.filter { !$0.isModuleBearingKind } == [.closure, .bankHoliday])
    }

    @Test("ModuleColour has the eight spec hex values and wraps round-robin")
    func moduleColour() {
        #expect(
            ModuleColour.allCases.map(\.hex) == [
                "#5E6AD2", "#4A9E6B", "#D9A441", "#B4695E",
                "#7B6BA8", "#3E8E9E", "#9A7B5E", "#6B7280",
            ])
        #expect(ModuleColour.roundRobin(0) == .indigo)
        #expect(ModuleColour.roundRobin(8) == .indigo)
        #expect(ModuleColour.roundRobin(9) == .green)
        #expect(ModuleColour.roundRobin(-1) == .slate)
    }

    @Test("the remaining supporting enums keep their spec order")
    func remainingEnums() {
        #expect(RevisionReason.allCases.map(\.rawValue) == ["idleSnapshot", "preSync", "conflictLoser"])
        #expect(DraftSource.allCases.map(\.rawValue) == ["inApp", "importedFile", "oneNote"])
        #expect(KSBCategory.allCases.map(\.rawValue) == ["knowledge", "skill", "behaviour"])
        #expect(CoverageLevel.allCases.map(\.rawValue) == ["none", "partial", "strong"])
        #expect(
            EvidenceSource.allCases.map(\.rawValue) == [
                "workProject", "assignment", "lecture", "reflection", "codeCommit",
            ])
        #expect(
            ProposalKind.allCases.map(\.rawValue) == [
                "newAssignment", "dateChange", "briefImported", "resourceImported",
                "hoursEntry", "evidenceSuggestion",
            ])
        #expect(
            ProposalSource.allCases.map(\.rawValue) == [
                "ele2", "universityMail", "workCalendar", "github", "programmeCalendar", "aiSuggestion",
            ])
        #expect(ProposalState.allCases.map(\.rawValue) == ["pending", "confirmed", "dismissed"])
        #expect(SubtaskOrigin.allCases.map(\.rawValue) == ["user", "workBackPlan"])
        #expect(
            AICapability.allCases.map(\.rawValue) == [
                "structureNotes", "makeFlashcards", "makeQuiz", "explain",
                "outline", "draftSection", "checkDraft", "suggestKSBs",
            ])
        #expect(
            AttachmentSourceKind.allCases.map(\.rawValue) == [
                "localFile", "oneDrive", "sharePoint", "github",
            ])
    }

    @Test("coverage is derived from evidence count: 0 none, 1–2 partial, 3+ strong")
    func coverageFromCount() {
        #expect(CoverageLevel.forEvidenceCount(0) == .none)
        #expect(CoverageLevel.forEvidenceCount(1) == .partial)
        #expect(CoverageLevel.forEvidenceCount(2) == .partial)
        #expect(CoverageLevel.forEvidenceCount(3) == .strong)
        #expect(CoverageLevel.forEvidenceCount(12) == .strong)
    }

    @Test("work-sourced evidence defaults to confidential")
    func workEvidenceConfidential() {
        #expect(EvidenceSource.workProject.defaultsToConfidential)
        #expect(EvidenceSource.codeCommit.defaultsToConfidential)
        #expect(!EvidenceSource.lecture.defaultsToConfidential)
    }
}
