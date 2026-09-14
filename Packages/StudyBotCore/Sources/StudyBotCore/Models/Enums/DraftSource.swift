/// Where an assignment's draft text comes from (spec §4, §6.2a). Every AI capability
/// works on `draftText` and neither knows nor cares about the source.
public enum DraftSource: String, Codable, CaseIterable, Hashable, Sendable {
    case inApp
    case importedFile
    case oneNote
}
