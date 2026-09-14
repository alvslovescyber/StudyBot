import Foundation

/// A captured copy of an assignment's draft text (spec §6.2a). Taken on every import and
/// every AI check so "what did the checker actually see" always has an answer. Last 30 kept.
public struct DraftSnapshot: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var text: String
    public var capturedAt: Date
    public var wordCount: Int
    public var source: DraftSource
    public var checkedByAI: Bool

    /// How many snapshots an assignment retains.
    public static let retained = 30

    public init(
        id: UUID = UUID(),
        text: String,
        capturedAt: Date,
        wordCount: Int,
        source: DraftSource,
        checkedByAI: Bool = false
    ) {
        self.id = id
        self.text = text
        self.capturedAt = capturedAt
        self.wordCount = wordCount
        self.source = source
        self.checkedByAI = checkedByAI
    }
}
