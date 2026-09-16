import Foundation

/// One message in a chat-style prompt. The client assembles these (§7.3a) and the server
/// wraps them in the provider's request; the client never knows the provider.
public struct AIMessage: Codable, Hashable, Sendable {
    public enum Role: String, Codable, Sendable {
        case system
        case user
    }

    public var role: Role
    public var content: String

    public init(role: Role, content: String) {
        self.role = role
        self.content = content
    }
}

/// Body of `POST /v1/ai/run` (§3.5, §3.7): a capability, the assembled prompt, and two flags
/// the server enforces. `containsConfidential` is the second line of defence: the client's
/// assembler never sets it true, and the server refuses with 422 if it ever is.
public struct AIRunRequest: Codable, Hashable, Sendable {
    public var schemaVersion: Int
    public var capability: AICapability
    public var messages: [AIMessage]
    /// True if anything in `messages` came from a work-confidential record. Must be false.
    public var containsConfidential: Bool
    /// Which piece of work this run is about, for the AI-use record (§7.5).
    public var assignmentID: UUID?
    /// The prompt template version, so a changed template is a new cache key.
    public var promptVersion: String

    public init(
        schemaVersion: Int = SyncSchema.current, capability: AICapability, messages: [AIMessage],
        containsConfidential: Bool = false, assignmentID: UUID? = nil, promptVersion: String
    ) {
        self.schemaVersion = schemaVersion
        self.capability = capability
        self.messages = messages
        self.containsConfidential = containsConfidential
        self.assignmentID = assignmentID
        self.promptVersion = promptVersion
    }
}

/// Response to `POST /v1/ai/run`: the text, and what it cost. `warning` is the 80% flag (§3.7).
public struct AIRunResponse: Codable, Hashable, Sendable {
    public var runID: UUID
    public var output: String
    public var model: String
    public var inputTokens: Int
    public var outputTokens: Int
    /// Integer pence (§3.13). Zero on a cache hit.
    public var costPence: Int
    public var cacheHit: Bool
    /// Spend is past 80% of the monthly cap.
    public var warning: Bool
    public var budget: AIBudget

    public init(
        runID: UUID, output: String, model: String, inputTokens: Int, outputTokens: Int, costPence: Int,
        cacheHit: Bool, warning: Bool, budget: AIBudget
    ) {
        self.runID = runID
        self.output = output
        self.model = model
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.costPence = costPence
        self.cacheHit = cacheHit
        self.warning = warning
        self.budget = budget
    }
}

/// `GET /v1/ai/budget` (§7.1): spend this month, the cap, what is left. Pence, integers.
public struct AIBudget: Codable, Hashable, Sendable {
    public var spentPence: Int
    public var capPence: Int
    public var remainingPence: Int { max(capPence - spentPence, 0) }
    /// Past 80% of the cap.
    public var isWarning: Bool { capPence > 0 && spentPence * 5 >= capPence * 4 }
    public var isExhausted: Bool { spentPence >= capPence }

    public init(spentPence: Int, capPence: Int) {
        self.spentPence = spentPence
        self.capPence = capPence
    }

    /// "£8.00".
    public static func pounds(_ pence: Int) -> String {
        let pounds = Double(pence) / 100
        return pounds == pounds.rounded() ? String(format: "£%.0f", pounds) : String(format: "£%.2f", pounds)
    }
}

/// Why the server refused an AI run, as the body of a 402, 422 or 429.
public struct AIRefusal: Codable, Hashable, Sendable {
    public enum Reason: String, Codable, Sendable {
        case budgetExhausted
        case confidential
        case rateLimited
        case providerUnavailable
    }

    public var reason: Reason
    public var budget: AIBudget?
    /// Seconds to wait, on a rate limit.
    public var retryAfterSeconds: Int?

    public init(reason: Reason, budget: AIBudget? = nil, retryAfterSeconds: Int? = nil) {
        self.reason = reason
        self.budget = budget
        self.retryAfterSeconds = retryAfterSeconds
    }
}
