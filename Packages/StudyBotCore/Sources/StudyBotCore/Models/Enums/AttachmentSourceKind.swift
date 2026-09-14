/// Where an attachment's bytes originally came from (spec §4 `Attachment.sourceKind`).
public enum AttachmentSourceKind: String, Codable, CaseIterable, Hashable, Sendable {
    case localFile
    case oneDrive
    case sharePoint
    case github
}
