import Foundation
import StudyBotCore
import Vapor

/// What a provider returns.
struct ProviderCompletion: Sendable {
    let text: String
    let inputTokens: Int
    let outputTokens: Int
}

/// The one seam to a model vendor (§3.7 "Provider seam"). Swapping vendor is this protocol
/// and one file; the client changes nothing.
protocol ModelProvider: Sendable {
    func complete(model: String, messages: [AIMessage]) async throws -> ProviderCompletion
}

struct ProviderError: Error, Sendable {
    let detail: String
}

/// OpenAI's chat completions endpoint through Vapor's HTTP client. The key never leaves
/// this process.
struct OpenAIProvider: ModelProvider {
    let client: any Client
    let apiKey: String

    func complete(model: String, messages: [AIMessage]) async throws -> ProviderCompletion {
        let body = OpenAIRequest(
            model: model, messages: messages.map { .init(role: $0.role.rawValue, content: $0.content) },
            temperature: 0.3)
        let response = try await client.post("https://api.openai.com/v1/chat/completions") { req in
            req.headers.bearerAuthorization = .init(token: apiKey)
            try req.content.encode(body)
        }
        guard response.status == .ok else {
            throw ProviderError(detail: "OpenAI answered HTTP \(response.status.code)")
        }
        let decoded = try response.content.decode(OpenAIResponse.self)
        guard let text = decoded.choices.first?.message.content else {
            throw ProviderError(detail: "OpenAI returned no text")
        }
        return ProviderCompletion(
            text: text, inputTokens: decoded.usage?.promptTokens ?? 0,
            outputTokens: decoded.usage?.completionTokens ?? 0)
    }
}

/// The wire shapes of the chat completions endpoint, kept flat and camel-cased.
private struct OpenAIRequest: Content {
    struct Message: Content {
        let role: String
        let content: String
    }
    let model: String
    let messages: [Message]
    let temperature: Double
}

private struct OpenAIMessage: Content {
    let content: String?
}

private struct OpenAIChoice: Content {
    let message: OpenAIMessage
}

private struct OpenAIUsage: Content {
    let promptTokens: Int?
    let completionTokens: Int?

    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
    }
}

private struct OpenAIResponse: Content {
    let choices: [OpenAIChoice]
    let usage: OpenAIUsage?
}
/// Local development and tests (§3.10b): canned answers, no network, no cost. Can be told to
/// fail, to exercise the provider-outage path.
actor CannedProvider: ModelProvider {
    var failing = false
    private(set) var calls = 0

    init() {}

    func setFailing(_ failing: Bool) { self.failing = failing }

    func complete(model: String, messages: [AIMessage]) async throws -> ProviderCompletion {
        calls += 1
        if failing { throw ProviderError(detail: "canned provider is down") }
        let prompt = messages.map(\.content).joined(separator: "\n")
        let text: String
        if prompt.contains("flashcards") {
            let cards = (1...10).map { index in
                "{\"front\": \"Question \(index)?\", \"back\": \"Answer \(index).\", \"sourceLine\": \"\"}"
            }
            text = "[\(cards.joined(separator: ", "))]"
        } else if prompt.contains("Summary (exactly 3 bullets)") {
            text =
                "## Summary\n- one\n- two\n- three\n\n## Key concepts\n- canned\n\n## Definitions\n\n## Worked examples\n\n## Exam-relevant points\n\n## Open questions\n- none"
        } else {
            text = "A canned explanation in plain language."
        }
        return ProviderCompletion(
            text: text, inputTokens: max(prompt.count / 4, 1), outputTokens: max(text.count / 4, 1))
    }
}
