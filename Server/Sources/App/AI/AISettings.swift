import Vapor

/// The AI proxy's configuration from the environment (§3.10b, §3.7).
struct AISettings: Sendable {
    let model: String
    let monthlyCapPence: Int
    /// Pence per million tokens, integers (§3.13).
    let inputPencePerMillion: Int
    let outputPencePerMillion: Int
    /// Requests per minute per device: overall, and for AI.
    let requestsPerMinute: Int
    let aiRequestsPerMinute: Int
    let cacheDays: Int

    static func fromEnvironment(_ environment: Environment) -> AISettings {
        func int(_ key: String, _ fallback: Int) -> Int { Environment.get(key).flatMap(Int.init) ?? fallback }
        return AISettings(
            model: Environment.get("OPENAI_MODEL") ?? "gpt-4o-mini",
            monthlyCapPence: int("AI_MONTHLY_CAP_PENCE", 800),
            inputPencePerMillion: int("AI_INPUT_PENCE_PER_MILLION_TOKENS", 12),
            outputPencePerMillion: int("AI_OUTPUT_PENCE_PER_MILLION_TOKENS", 48),
            requestsPerMinute: int("RATE_LIMIT_PER_MINUTE", environment == .testing ? 100 : 60),
            aiRequestsPerMinute: int("AI_RATE_LIMIT_PER_MINUTE", environment == .testing ? 5 : 10),
            cacheDays: 30)
    }

    /// Cost of a completion in pence, rounded up so the ledger never under-counts.
    func cost(inputTokens: Int, outputTokens: Int) -> Int {
        let pence =
            Double(inputTokens) * Double(inputPencePerMillion) / 1_000_000
            + Double(outputTokens) * Double(outputPencePerMillion) / 1_000_000
        return Int(pence.rounded(.up))
    }

    struct Key: StorageKey {
        typealias Value = AISettings
    }
}
