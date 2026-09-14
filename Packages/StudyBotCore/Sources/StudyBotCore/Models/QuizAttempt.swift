import Foundation

/// One run through an AI-generated quiz (spec §4). Attempts are stored so repeated weak
/// areas surface.
public struct QuizAttempt: Syncable {
    public static let recordType = "quizAttempt"

    public var sync: SyncMetadata
    public var deckID: UUID?
    public var sessionID: UUID?
    public var questions: [QuizQuestion]
    /// The chosen option index per question, aligned with `questions`.
    public var answers: [Int]
    /// Fraction correct, 0–1.
    public var score: Double
    public var takenAt: Date

    public init(
        sync: SyncMetadata,
        deckID: UUID? = nil,
        sessionID: UUID? = nil,
        questions: [QuizQuestion],
        answers: [Int],
        score: Double,
        takenAt: Date
    ) {
        self.sync = sync
        self.deckID = deckID
        self.sessionID = sessionID
        self.questions = questions
        self.answers = answers
        self.score = score
        self.takenAt = takenAt
    }
}
