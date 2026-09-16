import Foundation
import Observation
import StudyBotCore

/// The AI domain store (§7): three capabilities for now, each assembled through
/// `PromptAssembler` so the confidentiality guard runs on every path, sent through the paired
/// server, and recorded as an `AIRun` (§7.5). Live notes are never written by anything here.
@MainActor
@Observable
public final class AIStore {
    public private(set) var budget: AIBudget?
    public private(set) var running: Set<AICapability> = []
    /// The last failure, in §9's words, or nil.
    public private(set) var lastError: String?
    /// Whether `lastError` came from output the parser could not read, so Try again applies.
    public private(set) var canRetry = false
    /// The most recent `explain` answer.
    public private(set) var lastExplanation: String?
    /// The AI-use record (§7.5), newest first.
    public private(set) var runs: [AIRun] = []

    private let store: any RecordStore
    private let credentials: any SyncCredentialStore
    private let deviceID: String
    private let now: @Sendable () -> Date
    private let makeTransport: @Sendable (URL) -> any AITransport
    private var serverURL: URL?
    private let retrier = Retrier(maximumAttempts: 3, baseDelay: 1, maximumDelay: 20)

    public init(
        store: any RecordStore, credentials: any SyncCredentialStore, deviceID: String,
        makeTransport: @escaping @Sendable (URL) -> any AITransport = { HTTPAITransport(baseURL: $0) },
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.store = store
        self.credentials = credentials
        self.deviceID = deviceID
        self.makeTransport = makeTransport
        self.now = now
    }

    /// Which server to talk to; nil while unpaired.
    public func configure(serverURL: URL?) {
        self.serverURL = serverURL
    }

    public var isAvailable: Bool { serverURL != nil }

    public func load() async {
        runs = ((try? await store.fetchAll(AIRun.self, includeDeleted: false)) ?? []).map(\.value)
            .sorted { $0.timestamp > $1.timestamp }
    }

    public func refreshBudget() async {
        guard let transport, let token = try? credentials.token() else { return }
        budget = try? await transport.budget(token: token)
    }

    // MARK: Capabilities

    /// §7.2 `structureNotes`: live notes plus transcript in, markdown out, written to
    /// `structuredNotes` only. Returns the markdown, or nil with `lastError` set.
    public func structureNotes(session: Session, module: Module?, notes: NotesStore) async -> String? {
        let inputs = PromptAssembler.Inputs(
            moduleCode: module?.code, moduleName: module?.name,
            items: [
                AIContextItem(label: "Live notes", text: session.liveNotes),
                AIContextItem(label: "Transcript", text: session.transcript ?? ""),
            ])
        guard
            let response = await perform(
                .structureNotes, inputs: inputs, summary: "Structured the notes of \(session.title)")
        else {
            return nil
        }
        notes.setStructuredNotes(session.id, markdown: response.output)
        return response.output
    }

    /// §7.2 `makeFlashcards`: a deck from the structured notes. Returns the card count.
    public func makeFlashcards(session: Session, module: Module?) async -> Int? {
        guard let structured = session.structuredNotes, !structured.isEmpty else {
            lastError = "Structure these notes first; flashcards come from the structured notes."
            canRetry = false
            return nil
        }
        let inputs = PromptAssembler.Inputs(
            moduleCode: module?.code, moduleName: module?.name,
            items: [AIContextItem(label: "Structured notes", text: structured)])
        guard
            let response = await perform(
                .makeFlashcards, inputs: inputs, summary: "Made flashcards from \(session.title)")
        else {
            return nil
        }
        let drafts: [FlashcardDraft]
        do {
            drafts = try FlashcardParser.parse(response.output)
        } catch {
            lastError = "That came back unreadable. Try again?"
            canRetry = true
            return nil
        }
        let deck = Deck(
            sync: .new(at: now(), deviceID: deviceID), title: session.title, sessionID: session.id,
            moduleID: module?.id)
        let today = UKCalendar.startOfDay(now())
        let cards = drafts.map { draft in
            Card(
                sync: .new(at: now(), deviceID: deviceID), deckID: deck.id, front: draft.front,
                back: draft.back,
                source: draft.sourceLine, box: 1, dueDate: today, lapses: 0)
        }
        do {
            try await store.saveAll([deck])
            try await store.saveAll(cards)
        } catch {
            lastError = DiskSpace.saveFailureMessage(for: error, subject: "The deck")
            return nil
        }
        return cards.count
    }

    /// §7.2 `explain`: a term or question with the current notes as context.
    public func explain(_ question: String, session: Session?, module: Module?) async -> String? {
        var items = [AIContextItem(label: "Question", text: question)]
        if let session {
            items.append(AIContextItem(label: "Current notes", text: session.liveNotes))
        }
        let inputs = PromptAssembler.Inputs(moduleCode: module?.code, moduleName: module?.name, items: items)
        guard
            let response = await perform(
                .explain, inputs: inputs, summary: "Explained: \(question.prefix(80))")
        else {
            return nil
        }
        lastExplanation = response.output
        return response.output
    }

    /// Evidence and anything else that can be confidential goes through here first (§7.4).
    public func explainEvidence(_ evidence: Evidence, module: Module?) async -> String? {
        let inputs = PromptAssembler.Inputs(
            moduleCode: module?.code, moduleName: module?.name,
            items: [
                AIContextItem(
                    label: "Evidence", text: evidence.summary, isWorkConfidential: evidence.isWorkConfidential
                )
            ])
        return await perform(.explain, inputs: inputs, summary: "Explained evidence \(evidence.title)")?
            .output
    }

    // MARK: The one path to the server

    private var transport: (any AITransport)? { serverURL.map(makeTransport) }

    private func perform(_ capability: AICapability, inputs: PromptAssembler.Inputs, summary: String) async
        -> AIRunResponse?
    {
        lastError = nil
        canRetry = false
        let request: AIRunRequest
        do {
            request = try PromptAssembler.request(for: capability, inputs: inputs)
        } catch is ConfidentialContentError {
            lastError = ConfidentialContentError.userMessage
            return nil
        } catch {
            lastError = "That action is not available yet."
            return nil
        }
        guard let transport, let token = try? credentials.token() else {
            lastError = "AI needs the server. Pair this Mac in Settings → Sync; notes work without it."
            return nil
        }
        running.insert(capability)
        defer { running.remove(capability) }

        var attempt = 1
        while true {
            do {
                let response = try await transport.run(request, token: token)
                budget = response.budget
                await record(
                    response, capability: capability, summary: summary, assignmentID: inputs.assignmentID)
                return response
            } catch let AITransportError.refused(refusal) {
                guard let delay = handle(refusal, attempt: attempt) else { return nil }
                try? await Task.sleep(for: .seconds(delay))
                attempt += 1
            } catch {
                handle(error)
                return nil
            }
        }
    }

    /// Turns a refusal into §9's copy. Returns a delay to retry after, or nil to stop.
    private func handle(_ refusal: AIRefusal, attempt: Int) -> TimeInterval? {
        switch refusal.reason {
        case .budgetExhausted:
            let cap = refusal.budget.map { AIBudget.pounds($0.capPence) } ?? "the cap"
            lastError = "You've reached this month's AI limit of \(cap). Raise it in Settings → AI."
            if let budget = refusal.budget { self.budget = budget }
            return nil
        case .confidential:
            lastError = ConfidentialContentError.userMessage
            return nil
        case .rateLimited, .providerUnavailable:
            if let delay = retrier.delay(
                beforeAttempt: attempt, retryAfter: refusal.retryAfterSeconds.map(Double.init))
            {
                return delay
            }
            lastError =
                refusal.reason == .rateLimited
                ? "The AI is busy. Try again in a minute."
                : "The AI provider isn't answering. Your notes are safe; try again later."
            canRetry = true
            return nil
        }
    }

    private func handle(_ error: any Error) {
        switch error {
        case AITransportError.unauthorised:
            lastError = "The server no longer recognises this Mac. Pair it again in Settings → Sync."
        case AITransportError.unreachable:
            lastError = "Couldn't reach the server. AI needs it; notes do not."
            canRetry = true
        default:
            lastError = "That came back unreadable. Try again?"
            canRetry = true
        }
    }

    /// §7.5: every run writes an `AIRun`. Never the full prompt.
    private func record(
        _ response: AIRunResponse, capability: AICapability, summary: String, assignmentID: UUID?
    ) async {
        let run = AIRun(
            sync: .new(id: response.runID, at: now(), deviceID: deviceID), capability: capability,
            promptSummary: summary,
            inputTokens: response.inputTokens, outputTokens: response.outputTokens, model: response.model,
            output: response.output, acceptedByUser: true, timestamp: now(), assignmentID: assignmentID)
        try? await store.saveAll([run])
        runs.insert(run, at: 0)
    }
}
