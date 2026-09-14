/// Knowledge, Skills and Behaviours: the three categories of the apprenticeship standard (spec §4).
public enum KSBCategory: String, Codable, CaseIterable, Hashable, Sendable {
    case knowledge
    case skill
    case behaviour
}
