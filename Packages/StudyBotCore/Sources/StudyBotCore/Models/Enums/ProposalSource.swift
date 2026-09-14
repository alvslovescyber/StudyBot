/// Which upstream system produced a proposal (spec §4). Every queue row names its source.
public enum ProposalSource: String, Codable, CaseIterable, Hashable, Sendable {
    case ele2
    case universityMail
    case workCalendar
    case github
    case programmeCalendar
    case aiSuggestion
}
