import Foundation
import StudyBotCore
import StudyBotKit
import Testing

/// A server that answers from a script.
actor FakeAITransport: AITransport {
    var responses: [Result<AIRunResponse, AITransportError>] = []
    private(set) var requests: [AIRunRequest] = []

    func queue(_ result: Result<AIRunResponse, AITransportError>) { responses.append(result) }

    func run(_ request: AIRunRequest, token: String) async throws -> AIRunResponse {
        requests.append(request)
        guard !responses.isEmpty else { throw AITransportError.unreachable("no script") }
        return try responses.removeFirst().get()
    }

    func budget(token: String) async throws -> AIBudget { AIBudget(spentPence: 100, capPence: 800) }

    static func answer(_ output: String, cost: Int = 3) -> AIRunResponse {
        AIRunResponse(
            runID: UUID(), output: output, model: "test", inputTokens: 50, outputTokens: 20, costPence: cost,
            cacheHit: false, warning: false, budget: AIBudget(spentPence: 100 + cost, capPence: 800))
    }
}

@MainActor
@Suite("AIStore — the three capabilities, the guard, and the record")
struct AIStoreTests {
    private nonisolated static let t0 = SyncClient.t0

    private struct Harness {
        let ai: AIStore
        let notes: NotesStore
        let records: InMemoryRecordStore
        let transport: FakeAITransport
        let session: Session
    }

    private func makeHarness() async throws -> Harness {
        let records = InMemoryRecordStore()
        let transport = FakeAITransport()
        let notes = NotesStore(
            store: records, revisions: FakeRevisionStore(), deviceID: "air", now: { Self.t0 },
            saveDelay: .milliseconds(10))
        let ai = AIStore(
            store: records, credentials: InMemoryCredentialStore(token: "tok"), deviceID: "air",
            makeTransport: { _ in transport }, now: { Self.t0 })
        ai.configure(serverURL: URL(string: "https://studybot.example.com"))
        let events = try RealCalendar.events()
        let slot = try #require(SessionCatalog.slot(on: RealCalendar.day(2026, 9, 28), in: events))
        let session = await notes.open(slot, moduleID: nil)
        notes.updateLiveNotes(session.id, text: "- sets\nASK: does order matter\n")
        await notes.flush(session.id)
        return Harness(
            ai: ai, notes: notes, records: records, transport: transport,
            session: try #require(notes.session(id: session.id)))
    }

    @Test("structureNotes writes the structured pane, leaves live notes alone, and records the run")
    func structure() async throws {
        let h = try await makeHarness()
        await h.transport.queue(.success(FakeAITransport.answer("## Summary\n- one")))
        let output = await h.ai.structureNotes(session: h.session, module: nil, notes: h.notes)
        #expect(output == "## Summary\n- one")
        let after = try #require(h.notes.session(id: h.session.id))
        #expect(after.structuredNotes == "## Summary\n- one")
        #expect(after.liveNotes == "- sets\nASK: does order matter\n", "live notes untouched")
        let request = try #require(await h.transport.requests.first)
        #expect(request.capability == .structureNotes && !request.containsConfidential)
        #expect(request.messages[1].content.contains("### Live notes\n- sets"))
        #expect(h.ai.runs.count == 1 && h.ai.runs.first?.capability == .structureNotes)
        #expect(h.ai.runs.first?.promptSummary == "Structured the notes of Online lectures")
        #expect(h.ai.budget?.spentPence == 103)
        #expect(
            try await eventually {
                try await h.records.fetchAll(AIRun.self, includeDeleted: false).count == 1
            },
            "the AI-use record persists")
    }

    @Test("makeFlashcards needs structured notes, parses defensively, and saves a deck")
    func flashcards() async throws {
        let h = try await makeHarness()
        #expect(await h.ai.makeFlashcards(session: h.session, module: nil) == nil)
        #expect(h.ai.lastError?.contains("Structure these notes first") == true)

        h.notes.setStructuredNotes(h.session.id, markdown: "## Summary")
        let structured = try #require(h.notes.session(id: h.session.id))
        await h.transport.queue(.success(FakeAITransport.answer("not json at all")))
        #expect(await h.ai.makeFlashcards(session: structured, module: nil) == nil)
        #expect(h.ai.lastError == "That came back unreadable. Try again?" && h.ai.canRetry)

        await h.transport.queue(
            .success(
                FakeAITransport.answer(
                    "[{\"front\":\"What is a relation?\",\"back\":\"A subset of A × B.\",\"sourceLine\":\"\"},{\"front\":\"Define 3NF\",\"back\":\"No transitive dependencies.\"}]"
                )))
        #expect(await h.ai.makeFlashcards(session: structured, module: nil) == 2)
        #expect(try await h.records.fetchAll(Deck.self, includeDeleted: false).count == 1)
        #expect(try await h.records.fetchAll(Card.self, includeDeleted: false).count == 2)
    }

    @Test("refusals become §9's copy: budget, confidential, offline, and a retried rate limit")
    func refusals() async throws {
        let h = try await makeHarness()
        await h.transport.queue(
            .failure(
                .refused(
                    AIRefusal(reason: .budgetExhausted, budget: AIBudget(spentPence: 800, capPence: 800)))))
        #expect(await h.ai.explain("3NF", session: h.session, module: nil) == nil)
        #expect(h.ai.lastError == "You've reached this month's AI limit of £8. Raise it in Settings → AI.")

        let confidential = Evidence(
            sync: .new(at: Self.t0), title: "Incident", date: Self.t0, summary: "SECRET", source: .workProject
        )
        #expect(await h.ai.explainEvidence(confidential, module: nil) == nil)
        #expect(h.ai.lastError == ConfidentialContentError.userMessage)
        #expect(await h.transport.requests.count == 1, "the confidential item never left the Mac")

        await h.transport.queue(.failure(.refused(AIRefusal(reason: .rateLimited, retryAfterSeconds: 0))))
        await h.transport.queue(.success(FakeAITransport.answer("A relation is a subset.")))
        #expect(await h.ai.explain("relation", session: nil, module: nil) == "A relation is a subset.")
        #expect(h.ai.lastExplanation == "A relation is a subset.")

        await h.transport.queue(.failure(.unreachable("down")))
        #expect(await h.ai.explain("x", session: nil, module: nil) == nil)
        #expect(h.ai.lastError == "Couldn't reach the server. AI needs it; notes do not." && h.ai.canRetry)

        h.ai.configure(serverURL: nil)
        #expect(await h.ai.explain("x", session: nil, module: nil) == nil)
        #expect(h.ai.lastError?.hasPrefix("AI needs the server") == true)
    }
}
