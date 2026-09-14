/// A field of `OTJEntry` that can be mapped to an export column (spec §4 `ExportColumn`).
/// The export is configurable because Exeter's required format is unknown until induction
/// (§14, open question 2); an unexpected template is a settings change, not a migration.
public enum OTJField: String, Codable, CaseIterable, Hashable, Sendable {
    case date
    case hours
    case category
    case description
    case assignmentTitle
    case evidenceTitle
    case isSubmittedToProvider
}
