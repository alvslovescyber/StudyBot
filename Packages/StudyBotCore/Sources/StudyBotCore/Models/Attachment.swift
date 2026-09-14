import Foundation

/// A file attached to an assignment, session or piece of evidence (spec §4). Bytes never
/// travel through the sync envelope: they are content-addressed by SHA-256 and moved
/// through the blob routes (§3.4). The record carries the hash; the path is device-local.
public struct Attachment: Syncable {
    public static let recordType = "attachment"

    public var sync: SyncMetadata
    public var filename: String
    /// Uniform type identifier, e.g. `com.adobe.pdf`.
    public var uti: String
    /// Where the bytes live on this device. Not meaningful on the other Mac; it fetches by hash.
    public var localPath: String?
    /// Hex SHA-256 of the bytes, the blob store key. Nil until hashed.
    public var sha256: String?
    /// Size in bytes.
    public var byteCount: Int?
    /// From the importer.
    public var extractedText: String?
    public var sourceKind: AttachmentSourceKind
    public var remoteID: String?
    public var assignmentID: UUID?
    public var sessionID: UUID?
    public var evidenceID: UUID?

    public init(
        sync: SyncMetadata,
        filename: String,
        uti: String,
        localPath: String? = nil,
        sha256: String? = nil,
        byteCount: Int? = nil,
        extractedText: String? = nil,
        sourceKind: AttachmentSourceKind = .localFile,
        remoteID: String? = nil,
        assignmentID: UUID? = nil,
        sessionID: UUID? = nil,
        evidenceID: UUID? = nil
    ) {
        self.sync = sync
        self.filename = filename
        self.uti = uti
        self.localPath = localPath
        self.sha256 = sha256
        self.byteCount = byteCount
        self.extractedText = extractedText
        self.sourceKind = sourceKind
        self.remoteID = remoteID
        self.assignmentID = assignmentID
        self.sessionID = sessionID
        self.evidenceID = evidenceID
    }
}
