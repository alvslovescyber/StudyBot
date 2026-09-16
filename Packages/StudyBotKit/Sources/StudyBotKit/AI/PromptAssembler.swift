import Foundation
import StudyBotCore

/// One piece of context offered to a prompt, with the flag that decides whether it may go.
public struct AIContextItem: Hashable, Sendable {
    public let label: String
    public let text: String
    /// §7.4: true means this text can never reach a prompt, through any path.
    public let isWorkConfidential: Bool

    public init(label: String, text: String, isWorkConfidential: Bool = false) {
        self.label = label
        self.text = text
        self.isWorkConfidential = isWorkConfidential
    }
}

/// The confidentiality rule as an error: the caller shows §7.4's copy and does nothing else.
public struct ConfidentialContentError: Error, Equatable, Sendable {
    public let labels: [String]

    public init(labels: [String]) {
        self.labels = labels
    }

    public static let userMessage =
        "This is marked as work-confidential, so it isn't sent to the AI. You can still write, log and link it."
}

/// Assembles the request for a capability (§7.3a) from typed context. This is the one place
/// text becomes a prompt, which is what makes §7.4 enforceable: a confidential item throws
/// before any string is built, so it cannot appear in the output through any code path.
public enum PromptAssembler {
    public struct Inputs: Hashable, Sendable {
        public var moduleCode: String?
        public var moduleName: String?
        public var items: [AIContextItem]
        public var assignmentID: UUID?

        public init(
            moduleCode: String? = nil, moduleName: String? = nil, items: [AIContextItem],
            assignmentID: UUID? = nil
        ) {
            self.moduleCode = moduleCode
            self.moduleName = moduleName
            self.items = items
            self.assignmentID = assignmentID
        }
    }

    /// Builds the request, or throws if any item is confidential.
    public static func request(for capability: AICapability, inputs: Inputs) throws -> AIRunRequest {
        let confidential = inputs.items.filter(\.isWorkConfidential).map(\.label)
        guard confidential.isEmpty else { throw ConfidentialContentError(labels: confidential) }

        let system = PromptTemplates.contextBlock(
            moduleCode: inputs.moduleCode, moduleName: inputs.moduleName)
        let instruction: String
        switch capability {
        case .structureNotes: instruction = PromptTemplates.structureNotes
        case .makeFlashcards: instruction = PromptTemplates.makeFlashcards
        case .explain: instruction = PromptTemplates.explain
        case .makeQuiz, .outline, .draftSection, .checkDraft, .suggestKSBs:
            throw UnsupportedCapability(capability: capability)
        }
        var user = [instruction, ""]
        for item in inputs.items where !item.text.isEmpty {
            user.append("### \(item.label)")
            user.append(item.text)
            user.append("")
        }
        return AIRunRequest(
            capability: capability,
            messages: [
                AIMessage(role: .system, content: system),
                AIMessage(
                    role: .user, content: user.joined(separator: "\n").trimmingCharacters(in: .newlines)),
            ],
            containsConfidential: false, assignmentID: inputs.assignmentID,
            promptVersion: PromptTemplates.version)
    }

    /// The capabilities this build's prompts cover; the rest arrive with their screens.
    public static let supported: [AICapability] = [.structureNotes, .makeFlashcards, .explain]
}

public struct UnsupportedCapability: Error, Equatable, Sendable {
    public let capability: AICapability

    public init(capability: AICapability) {
        self.capability = capability
    }
}
