/// One multiple-choice question in a `QuizAttempt` (spec §4).
public struct QuizQuestion: Codable, Hashable, Sendable {
    public var prompt: String
    public var options: [String]
    /// Index into `options`.
    public var correctIndex: Int
    public var explanation: String

    public init(prompt: String, options: [String], correctIndex: Int, explanation: String) {
        self.prompt = prompt
        self.options = options
        self.correctIndex = correctIndex
        self.explanation = explanation
    }
}
