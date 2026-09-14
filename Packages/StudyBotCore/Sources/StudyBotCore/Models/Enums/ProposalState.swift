/// Lifecycle of a proposal (spec §4). Dismissed rows are kept so the same upstream item
/// is never proposed twice; proposals never expire.
public enum ProposalState: String, Codable, CaseIterable, Hashable, Sendable {
    case pending
    case confirmed
    case dismissed
}
