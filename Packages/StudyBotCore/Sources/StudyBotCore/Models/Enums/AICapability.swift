/// The AI capabilities the server proxy exposes (spec §7.2). Each has its own prompt,
/// its own context assembly and its own row in the AI-use record.
public enum AICapability: String, Codable, CaseIterable, Hashable, Sendable {
    case structureNotes
    case makeFlashcards
    case makeQuiz
    case explain
    case outline
    case draftSection
    case checkDraft
    case suggestKSBs

    /// Whether the capability returns JSON the client must parse defensively (§7.3).
    public var returnsJSON: Bool {
        switch self {
        case .makeFlashcards, .makeQuiz, .checkDraft, .suggestKSBs: true
        case .structureNotes, .explain, .outline, .draftSection: false
        }
    }
}
