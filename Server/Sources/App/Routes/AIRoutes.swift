import Fluent
import StudyBotCore
import Vapor

/// `POST /v1/ai/run` and `GET /v1/ai/budget` (§3.5, §3.7). Logs the capability and the token
/// counts, never the prompt or the answer (§3.10).
struct AIRoutes: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let ai = routes.grouped("ai")

        ai.post("run") { req async throws -> Response in
            let body = try req.content.decode(AIRunRequest.self, using: SyncContentDecoder())
            do {
                try SchemaGuard.check(body.schemaVersion)
            } catch let refused as SchemaRefusedError {
                return try SyncContentEncoder.response(refused.refusal, status: .conflict)
            }
            guard let device = req.auth.get(DeviceToken.self)?.id else { throw Abort(.unauthorized) }
            let service = req.application.aiService(on: req.db)
            switch try await service.run(body, device: device) {
            case .completed(let response):
                req.logger.info(
                    "ai run: \(body.capability.rawValue) \(response.inputTokens)+\(response.outputTokens) tokens, \(response.costPence)p\(response.cacheHit ? ", cache hit" : "")"
                )
                return try SyncContentEncoder.response(response, status: .ok)
            case .refused(let refusal, let status):
                req.logger.info("ai refused: \(refusal.reason.rawValue)")
                return try SyncContentEncoder.response(refusal, status: status)
            }
        }

        ai.get("budget") { req async throws -> Response in
            let budget = try await req.application.aiService(on: req.db).budget()
            return try SyncContentEncoder.response(budget, status: .ok)
        }
    }
}

extension Application {
    struct ProviderKey: StorageKey {
        typealias Value = any ModelProvider
    }

    var aiSettings: AISettings {
        storage[AISettings.Key.self] ?? AISettings.fromEnvironment(environment)
    }

    var modelProvider: any ModelProvider {
        get {
            if let stored = storage[ProviderKey.self] { return stored }
            let provider: any ModelProvider
            if let key = Environment.get("OPENAI_API_KEY"), !key.isEmpty, environment != .testing {
                provider = OpenAIProvider(client: client, apiKey: key)
            } else {
                provider = CannedProvider()
            }
            storage[ProviderKey.self] = provider
            return provider
        }
        set { storage[ProviderKey.self] = newValue }
    }

    var budgetGate: BudgetGate {
        if let gate = storage[BudgetGate.Key.self] { return gate }
        let gate = BudgetGate()
        storage[BudgetGate.Key.self] = gate
        return gate
    }

    func aiService(on db: any Database, now: Date = Date()) -> AIService {
        AIService(db: db, provider: modelProvider, settings: aiSettings, gate: budgetGate, now: now)
    }
}
