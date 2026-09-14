import Foundation

/// Something automation suggests, awaiting the user's confirmation (spec §4, §8.7).
///
/// Rules: never auto-applied. Confirming applies `payload` and sets `state = .confirmed`.
/// Dismissing keeps the row so the same upstream item is never proposed twice. Proposals
/// never expire. Uniqueness is `(source, sourceRef, kind)`.
public struct Proposal: Syncable {
    public static let recordType = "proposal"

    public var sync: SyncMetadata
    public var kind: ProposalKind
    public var source: ProposalSource
    /// Upstream id; makes ingestion idempotent.
    public var sourceRef: String
    /// One line, as shown in the queue.
    public var title: String
    /// The proposed change, an encoded Codable DTO.
    public var payload: Data
    /// The record it would modify, if it exists.
    public var targetID: UUID?
    public var state: ProposalState
    /// Feeds back into classification.
    public var dismissedReason: String?
    public var resolvedAt: Date?

    public init(
        sync: SyncMetadata,
        kind: ProposalKind,
        source: ProposalSource,
        sourceRef: String,
        title: String,
        payload: Data,
        targetID: UUID? = nil,
        state: ProposalState = .pending,
        dismissedReason: String? = nil,
        resolvedAt: Date? = nil
    ) {
        self.sync = sync
        self.kind = kind
        self.source = source
        self.sourceRef = sourceRef
        self.title = title
        self.payload = payload
        self.targetID = targetID
        self.state = state
        self.dismissedReason = dismissedReason
        self.resolvedAt = resolvedAt
    }

    /// The tuple that makes a proposal unique.
    public struct Key: Hashable, Sendable {
        public let source: ProposalSource
        public let sourceRef: String
        public let kind: ProposalKind
    }

    /// The uniqueness key `(source, sourceRef, kind)`.
    public var key: Key { Key(source: source, sourceRef: sourceRef, kind: kind) }
}
