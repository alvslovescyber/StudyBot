import Foundation
import StudyBotCore
import Testing
import VaporTesting

@testable import App

/// §3.12 rows "Confidentiality guard" (server half), "AI budget", "AI cache", "Rate limiter".
@Suite("AI proxy routes", .serialized)
struct AIRoutesTests {
    private func withServer(_ body: (Application, String) async throws -> Void) async throws {
        try await withApp(configure: configure) { app in
            let code = try await Pairing.issueCode(
                on: app.db, secret: app.settings.pairingSecret, now: Date())
            let paired = try await Pairing.redeem(
                PairRequest(code: code, deviceName: "Air"), on: app.db, secret: app.settings.pairingSecret,
                now: Date())
            try await body(app, paired.token)
        }
    }

    private func request(
        _ capability: AICapability = .explain, text: String = "transitive dependency",
        confidential: Bool = false
    )
        -> AIRunRequest
    {
        AIRunRequest(
            capability: capability,
            messages: [AIMessage(role: .system, content: "context"), AIMessage(role: .user, content: text)],
            containsConfidential: confidential, promptVersion: "test")
    }

    private func run(_ app: Application, token: String, _ body: AIRunRequest) async throws -> (
        HTTPStatus, Data
    ) {
        var result: (HTTPStatus, Data) = (.internalServerError, Data())
        try await app.testing().test(
            .POST, "v1/ai/run",
            beforeRequest: { req in
                req.headers.bearerAuthorization = .init(token: token)
                req.headers.contentType = .json
                req.body = ByteBuffer(data: try SyncCoding.encode(body))
            },
            afterResponse: { res in result = (res.status, Data(res.body.readableBytesView)) })
        return result
    }

    @Test("a payload flagged confidential is refused with 422 and never reaches the provider")
    func confidentialRefused() async throws {
        try await withServer { app, token in
            let provider = CannedProvider()
            app.modelProvider = provider
            let (status, data) = try await run(app, token: token, request(confidential: true))
            #expect(status == .unprocessableEntity)
            #expect(try SyncCoding.decode(AIRefusal.self, from: data).reason == .confidential)
            #expect(await provider.calls == 0)
            #expect(try await AIRunRow.query(on: app.db).count() == 0, "nothing is recorded or charged")
        }
    }

    @Test("a run is answered, recorded and charged; the same input hits the cache and costs nothing")
    func runAndCache() async throws {
        try await withServer { app, token in
            let provider = CannedProvider()
            app.modelProvider = provider
            let (status, data) = try await run(
                app, token: token, request(text: "explain   transitive\ndependency"))
            #expect(status == .ok)
            let first = try SyncCoding.decode(AIRunResponse.self, from: data)
            #expect(!first.cacheHit && first.costPence >= 1 && first.output.contains("canned"))
            let spentAfterFirst = first.budget.spentPence
            #expect(spentAfterFirst == first.costPence)

            // Whitespace-only change: still a hit, still free, not counted.
            let (status2, data2) = try await run(
                app, token: token, request(text: "explain transitive dependency"))
            #expect(status2 == .ok)
            let second = try SyncCoding.decode(AIRunResponse.self, from: data2)
            #expect(second.cacheHit && second.costPence == 0)
            #expect(second.output == first.output)
            #expect(second.budget.spentPence == spentAfterFirst, "a cache hit is not counted")
            #expect(await provider.calls == 1)

            // A different capability with the same text misses.
            let (status3, data3) = try await run(
                app, token: token, request(.structureNotes, text: "explain transitive dependency"))
            #expect(status3 == .ok)
            #expect(try SyncCoding.decode(AIRunResponse.self, from: data3).cacheHit == false)
            #expect(await provider.calls == 2)
            #expect(
                try await AIRunRow.query(on: app.db).count() == 3, "every run is in the ledger, hits included"
            )
        }
    }

    @Test("the budget warns at 80% and blocks at 100% with 402 naming the remaining budget")
    func budgetCap() async throws {
        try await withServer { app, token in
            app.modelProvider = CannedProvider()
            // A cap of one penny: the first canned run spends it all.
            let stored = app.aiSettings
            let tiny = AISettings(
                model: stored.model, monthlyCapPence: 1, inputPencePerMillion: stored.inputPencePerMillion,
                outputPencePerMillion: stored.outputPencePerMillion,
                requestsPerMinute: stored.requestsPerMinute,
                aiRequestsPerMinute: stored.aiRequestsPerMinute, cacheDays: 30)
            app.storage[AISettings.Key.self] = tiny
            let (status, data) = try await run(app, token: token, request(text: "first"))
            #expect(status == .ok)
            let first = try SyncCoding.decode(AIRunResponse.self, from: data)
            #expect(first.warning || first.budget.isExhausted, "one penny of two is past 80%")
            // Force the ledger to the cap.
            try await AIRunRow(
                capability: "explain", model: "m", inputTokens: 0, outputTokens: 0, costPence: 2,
                cacheHit: false,
                createdAt: Date(), relatedAssignmentID: nil, deviceID: UUID()
            ).save(on: app.db)
            let (blocked, refusalData) = try await run(app, token: token, request(text: "second"))
            #expect(blocked == .paymentRequired)
            let refusal = try SyncCoding.decode(AIRefusal.self, from: refusalData)
            #expect(refusal.reason == .budgetExhausted)
            #expect(refusal.budget?.remainingPence == 0)

            try await app.testing().test(
                .GET, "v1/ai/budget",
                beforeRequest: { req in req.headers.bearerAuthorization = .init(token: token) },
                afterResponse: { res in
                    #expect(res.status == .ok)
                    let budget = try SyncCoding.decode(AIBudget.self, from: Data(res.body.readableBytesView))
                    #expect(budget.isExhausted && budget.capPence == 1)
                })
        }
    }

    @Test("concurrent requests cannot together exceed the cap")
    func concurrentCap() async throws {
        try await withServer { app, token in
            app.modelProvider = CannedProvider()
            let stored = app.aiSettings
            // Each canned run costs about a penny; the cap allows one.
            app.storage[AISettings.Key.self] = AISettings(
                model: stored.model, monthlyCapPence: 1, inputPencePerMillion: 1_000_000,
                outputPencePerMillion: 1_000_000,
                requestsPerMinute: stored.requestsPerMinute, aiRequestsPerMinute: 100, cacheDays: 30)
            var statuses: [HTTPStatus] = []
            await withTaskGroup(of: HTTPStatus.self) { group in
                for index in 0..<4 {
                    group.addTask {
                        (try? await self.run(
                            app, token: token, self.request(text: "distinct prompt \(index)")))?.0
                            ?? .internalServerError
                    }
                }
                for await status in group { statuses.append(status) }
            }
            #expect(statuses.filter { $0 == .ok }.count == 1, "\(statuses)")
            #expect(statuses.filter { $0 == .paymentRequired }.count == 3)
        }
    }

    @Test("a provider outage is a 502 the client can read, and nothing is charged")
    func providerDown() async throws {
        try await withServer { app, token in
            let provider = CannedProvider()
            await provider.setFailing(true)
            app.modelProvider = provider
            let (status, data) = try await run(app, token: token, request(text: "anything"))
            #expect(status == .badGateway)
            #expect(try SyncCoding.decode(AIRefusal.self, from: data).reason == .providerUnavailable)
            #expect(try await AIRunRow.query(on: app.db).count() == 0)
        }
    }

    @Test("the AI rate limit answers 429 with Retry-After after the per-minute burst")
    func rateLimited() async throws {
        try await withServer { app, token in
            app.modelProvider = CannedProvider()
            var statuses: [HTTPStatus] = []
            var retryAfter: String?
            for index in 0..<7 {
                var headers: HTTPHeaders?
                let (status, _) = try await run(app, token: token, request(text: "prompt \(index)"))
                statuses.append(status)
                if status == .tooManyRequests {
                    try await app.testing().test(
                        .POST, "v1/ai/run",
                        beforeRequest: { req in
                            req.headers.bearerAuthorization = .init(token: token)
                            req.headers.contentType = .json
                            req.body = ByteBuffer(data: try SyncCoding.encode(self.request(text: "again")))
                        },
                        afterResponse: { res in headers = res.headers })
                    retryAfter = headers?.first(name: .retryAfter)
                    break
                }
            }
            #expect(
                statuses.filter { $0 == .ok }.count == 5, "the testing limit is five a minute: \(statuses)")
            #expect(statuses.last == .tooManyRequests)
            #expect((retryAfter.flatMap(Int.init) ?? 0) >= 1)
        }
    }
}
