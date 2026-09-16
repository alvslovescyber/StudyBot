import Foundation
import StudyBotCore

/// One card as the model returns it (§7.3a `makeFlashcards`).
public struct FlashcardDraft: Codable, Hashable, Sendable {
    public var front: String
    public var back: String
    public var sourceLine: String?
}

/// Parses `makeFlashcards` output defensively (§7.3 "JSON-returning capabilities … parse
/// defensively"): finds the array even inside a code fence or prose, drops cards missing a
/// side, and refuses yes/no fronts as the template forbids them.
public enum FlashcardParser {
    public enum Failure: Error, Equatable, Sendable {
        /// §9: "That came back unreadable. Try again?"
        case unreadable
        case empty
    }

    public static func parse(_ output: String) throws -> [FlashcardDraft] {
        guard let start = output.firstIndex(of: "["), let end = output.lastIndex(of: "]"), start < end else {
            throw Failure.unreadable
        }
        let json = String(output[start...end])
        let decoded: [FlashcardDraft]
        do {
            decoded = try JSONDecoder().decode([FlashcardDraft].self, from: Data(json.utf8))
        } catch {
            throw Failure.unreadable
        }
        let cards = decoded.compactMap { card -> FlashcardDraft? in
            let front = card.front.trimmingCharacters(in: .whitespacesAndNewlines)
            let back = card.back.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !front.isEmpty, !back.isEmpty, !isYesNo(front) else { return nil }
            return FlashcardDraft(front: front, back: back, sourceLine: card.sourceLine)
        }
        guard !cards.isEmpty else { throw Failure.empty }
        return cards
    }

    /// "Is…", "Does…", "Can…" fronts can be answered yes or no.
    static func isYesNo(_ front: String) -> Bool {
        let first =
            front.split(separator: " ").first.map {
                $0.lowercased().trimmingCharacters(in: .punctuationCharacters)
            } ?? ""
        return ["is", "are", "does", "do", "can", "did", "was", "were", "will", "has", "have", "should"]
            .contains(first)
    }
}
