import Crypto
import Fluent
import Foundation
import StudyBotCore
import Vapor

/// The proxy's rules (§3.7), in one place because this is the only place they can be
/// enforced: confidentiality, cache, hard cap, accounting, provider seam.
struct AIService {
    let db: any Database
    let provider: any ModelProvider
    let settings: AISettings
    let gate: BudgetGate
    let now: Date

    enum Outcome: Sendable {
        case completed(AIRunResponse)
        case refused(AIRefusal, HTTPStatus)
    }

    func run(_ request: AIRunRequest, device: UUID) async throws -> Outcome {
        // Defence in depth (§7.4): the client's assembler never sets this; the server refuses anyway.
        guard !request.containsConfidential else {
            return .refused(AIRefusal(reason: .confidential), .unprocessableEntity)
        }
        let hash = Self.cacheKey(request, model: settings.model)
        if let cached = try await cachedResponse(hash) {
            let budget = try await budget()
            try await record(
                request, device: device,
                Accounting(
                    inputTokens: cached.inputTokens, outputTokens: cached.outputTokens, cost: 0,
                    cacheHit: true))
            return .completed(
                AIRunResponse(
                    runID: UUID(), output: cached.response, model: cached.model,
                    inputTokens: cached.inputTokens,
                    outputTokens: cached.outputTokens, costPence: 0, cacheHit: true,
                    warning: budget.isWarning,
                    budget: budget))
        }

        // Reserve the worst plausible cost before calling, so concurrent requests cannot
        // together pass the cap (§3.12 "concurrent requests cannot exceed the cap").
        let estimate = settings.cost(
            inputTokens: request.messages.reduce(0) { $0 + $1.content.count / 4 }, outputTokens: 1_500)
        let spent = try await spentThisMonth()
        guard await gate.reserve(estimate, spent: spent, cap: settings.monthlyCapPence) else {
            return .refused(
                AIRefusal(
                    reason: .budgetExhausted,
                    budget: AIBudget(spentPence: spent, capPence: settings.monthlyCapPence)),
                .paymentRequired)
        }
        let completion: ProviderCompletion
        do {
            completion = try await provider.complete(model: settings.model, messages: request.messages)
        } catch {
            await gate.release(estimate)
            return .refused(AIRefusal(reason: .providerUnavailable), .badGateway)
        }
        let cost = settings.cost(inputTokens: completion.inputTokens, outputTokens: completion.outputTokens)
        try await record(
            request, device: device,
            Accounting(
                inputTokens: completion.inputTokens, outputTokens: completion.outputTokens, cost: cost,
                cacheHit: false))
        try await AICacheRow(
            hash: hash, capability: request.capability.rawValue, model: settings.model,
            response: completion.text,
            inputTokens: completion.inputTokens, outputTokens: completion.outputTokens, createdAt: now
        ).save(on: db)
        await gate.release(estimate)
        let budget = try await budget()
        return .completed(
            AIRunResponse(
                runID: UUID(), output: completion.text, model: settings.model,
                inputTokens: completion.inputTokens,
                outputTokens: completion.outputTokens, costPence: cost, cacheHit: false,
                warning: budget.isWarning,
                budget: budget))
    }

    func budget() async throws -> AIBudget {
        AIBudget(spentPence: try await spentThisMonth(), capPence: settings.monthlyCapPence)
    }

    // MARK: Internals

    /// Spend since the first of the month, London time.
    func spentThisMonth() async throws -> Int {
        let start = UKCalendar.calendar.dateInterval(of: .month, for: now)?.start ?? now
        let rows = try await AIRunRow.query(on: db).filter(\.$createdAt >= start.timeIntervalSince1970).all()
        return rows.reduce(0) { $0 + $1.costPence }
    }

    private func cachedResponse(_ hash: String) async throws -> AICacheRow? {
        guard let row = try await AICacheRow.find(hash, on: db) else { return nil }
        let age = now.timeIntervalSince1970 - row.createdAt
        return age <= Double(settings.cacheDays) * 86_400 ? row : nil
    }

    /// What a run cost, for the ledger.
    struct Accounting {
        let inputTokens: Int
        let outputTokens: Int
        let cost: Int
        let cacheHit: Bool
    }

    private func record(_ request: AIRunRequest, device: UUID, _ accounting: Accounting) async throws {
        let (inputTokens, outputTokens, cost, cacheHit) = (
            accounting.inputTokens, accounting.outputTokens, accounting.cost, accounting.cacheHit
        )
        try await AIRunRow(
            capability: request.capability.rawValue, model: settings.model, inputTokens: inputTokens,
            outputTokens: outputTokens, costPence: cost, cacheHit: cacheHit, createdAt: now,
            relatedAssignmentID: request.assignmentID, deviceID: device
        ).save(on: db)
    }

    /// SHA-256 of capability, model, template version and the whitespace-normalised prompt, so
    /// a re-run after reformatting the same notes hits.
    static func cacheKey(_ request: AIRunRequest, model: String) -> String {
        let normalised = request.messages.map { message in
            message.role.rawValue + ":"
                + message.content.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        }.joined(separator: "\n")
        let input = "\(request.capability.rawValue)|\(model)|\(request.promptVersion)|\(normalised)"
        return SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

/// Serialises budget reservations so two requests in flight cannot both squeeze under the cap.
actor BudgetGate {
    private var reserved = 0

    init() {}

    func reserve(_ pence: Int, spent: Int, cap: Int) -> Bool {
        guard spent < cap, spent + reserved + pence <= max(cap, spent + pence) else { return false }
        // The cap is on realised spend: a request may start while under the cap even if its
        // worst case would cross it, but two may not both start on the same headroom.
        guard spent + reserved < cap else { return false }
        reserved += pence
        return true
    }

    func release(_ pence: Int) {
        reserved = max(reserved - pence, 0)
    }

    struct Key: StorageKey {
        typealias Value = BudgetGate
    }
}
