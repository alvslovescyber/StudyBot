import Foundation

/// One AI call, recorded so "where did AI help on this piece of work" has a real answer
/// (spec §4, §7.5). This is the AI-use record. Token counts are integers (§3.13).
public struct AIRun: Syncable {
    public static let recordType = "aiRun"

    public var sync: SyncMetadata
    public var capability: AICapability
    /// Human-readable, for the AI-use record. Never the full prompt.
    public var promptSummary: String
    public var inputTokens: Int
    public var outputTokens: Int
    public var model: String
    public var output: String
    public var acceptedByUser: Bool
    public var timestamp: Date
    public var assignmentID: UUID?

    public init(
        sync: SyncMetadata,
        capability: AICapability,
        promptSummary: String,
        inputTokens: Int,
        outputTokens: Int,
        model: String,
        output: String,
        acceptedByUser: Bool = false,
        timestamp: Date,
        assignmentID: UUID? = nil
    ) {
        self.sync = sync
        self.capability = capability
        self.promptSummary = promptSummary
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.model = model
        self.output = output
        self.acceptedByUser = acceptedByUser
        self.timestamp = timestamp
        self.assignmentID = assignmentID
    }
}
