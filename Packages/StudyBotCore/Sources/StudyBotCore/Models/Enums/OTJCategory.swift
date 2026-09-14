/// Off-the-job learning category (spec §4 Supporting types, which is the authoritative
/// list; the `OTJEntry` model listing omits `workshop`).
public enum OTJCategory: String, Codable, CaseIterable, Hashable, Sendable {
    case lecture
    case workshop
    case selfStudy
    case mentoring
    case shadowing
    case projectWork
    case research
    case writingUp
    case training
}
