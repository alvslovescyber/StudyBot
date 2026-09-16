import Fluent
import Foundation
import Vapor

/// `ai_runs` (§4 server-only tables, §3.7): the budget ledger and the AI-use record.
final class AIRunRow: Model, @unchecked Sendable {
    static let schema = "ai_runs"

    @ID(key: .id) var id: UUID?
    @Field(key: "capability") var capability: String
    @Field(key: "model") var model: String
    @Field(key: "input_tokens") var inputTokens: Int
    @Field(key: "output_tokens") var outputTokens: Int
    @Field(key: "cost_pence") var costPence: Int
    @Field(key: "cache_hit") var cacheHit: Bool
    @Field(key: "created_at") var createdAt: Double
    @OptionalField(key: "related_assignment_id") var relatedAssignmentID: UUID?
    @Field(key: "device_id") var deviceID: UUID

    init() {}

    init(
        capability: String, model: String, inputTokens: Int, outputTokens: Int, costPence: Int,
        cacheHit: Bool,
        createdAt: Date, relatedAssignmentID: UUID?, deviceID: UUID
    ) {
        self.capability = capability
        self.model = model
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.costPence = costPence
        self.cacheHit = cacheHit
        self.createdAt = createdAt.timeIntervalSince1970
        self.relatedAssignmentID = relatedAssignmentID
        self.deviceID = deviceID
    }
}
