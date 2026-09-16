import Fluent
import Foundation
import Vapor

/// `ai_cache` (§3.7): keyed on SHA-256 of capability, model, template version and the
/// normalised input. Thirty-day TTL. A hit costs nothing and is not counted.
final class AICacheRow: Model, @unchecked Sendable {
    static let schema = "ai_cache"

    @ID(custom: "input_hash", generatedBy: .user) var id: String?
    @Field(key: "capability") var capability: String
    @Field(key: "model") var model: String
    @Field(key: "response") var response: String
    @Field(key: "input_tokens") var inputTokens: Int
    @Field(key: "output_tokens") var outputTokens: Int
    @Field(key: "created_at") var createdAt: Double

    init() {}

    init(
        hash: String, capability: String, model: String, response: String, inputTokens: Int,
        outputTokens: Int, createdAt: Date
    ) {
        id = hash
        self.capability = capability
        self.model = model
        self.response = response
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.createdAt = createdAt.timeIntervalSince1970
    }
}
