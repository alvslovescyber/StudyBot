/// What a proposal in the Needs a moment queue would do (spec §4, §8.7).
public enum ProposalKind: String, Codable, CaseIterable, Hashable, Sendable {
    case newAssignment
    case dateChange
    case briefImported
    case resourceImported
    case hoursEntry
    case evidenceSuggestion
}
