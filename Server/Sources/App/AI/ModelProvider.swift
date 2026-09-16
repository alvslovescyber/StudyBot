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

    private struct Request: Content {
        struct Message: Content {
            let role: String
            let content: String
        }
        let model: String
        let messages: [Message]
        let temperature: Double
    }

    private struct Response: Content {
        struct Choice: Content {
            struct Message: Content {
                let content: String?
            }
            let message: Message
        }
        struct Usage: Content {
            let prompt_tokens: Int?
            let completion_tokens: Int?
        }
        let choices: [Choice]
        let usage: Usage?
    }

    func complete(model: String, messages: [AIMessage]) async throws -> ProviderCompletion {
        let body = Request(
            model: model, messages: messages.map { .init(role: $0.role.rawValue, content: $0.content) },
            temperature: 0.3)
        let response = try await client.post("https://api.openai.com/v1/chat/completions") { req in
            req.headers.bearerAuthorization = .init(token: apiKey)
            try req.content.encode(body)
        }
        guard response.status == .ok else {
            throw ProviderError(detail: "OpenAI answered HTTP \(response.status.code)")
        }
        let decoded = try response.content.decode(Response.self)
        guard let text = decoded.choices.first?.message.content else {
            throw ProviderError(detail: "OpenAI returned no text")
        }
        return ProviderCompletion(
            text: text, inputTokens: decoded.usage?.prompt_tokens ?? 0,
            outputTokens: decoded.usage?.completion_tokens ?? 0)
    }
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
