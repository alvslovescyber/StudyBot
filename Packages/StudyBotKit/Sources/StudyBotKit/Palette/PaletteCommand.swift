import Foundation

/// One entry in the ⌘K palette (§6.7): navigation or an action. AI entries arrive with the
/// AI milestone; full-text search with the search index.
public struct PaletteCommand: Identifiable, Hashable, Sendable {
    public enum Section: String, Hashable, Sendable, CaseIterable {
        case actions = "Actions"
        case goTo = "Go to"
    }

    public let id: String
    public let section: Section
    public let title: String
    /// A second line: "23 Sep", "COM1018DA", a shortcut.
    public let detail: String?
    /// Extra words the match may hit: a module code, a date.
    public let keywords: [String]

    public init(id: String, section: Section, title: String, detail: String? = nil, keywords: [String] = []) {
        self.id = id
        self.section = section
        self.title = title
        self.detail = detail
        self.keywords = keywords
    }
}

/// Filters and ranks palette commands for a query. Pure, so the ranking is testable.
public enum PaletteMatcher {
    /// Commands matching `query`, best first. An empty query returns everything in the given
    /// order, actions first.
    public static func matches(_ query: String, in commands: [PaletteCommand]) -> [PaletteCommand] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return commands }
        return
            commands
            .compactMap { command in score(trimmed, command).map { (command, $0) } }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }

    /// Higher is better; nil is no match. Prefix of the title beats a word start, which beats
    /// a subsequence; keywords count a little less than the title.
    static func score(_ query: String, _ command: PaletteCommand) -> Int? {
        let needle = query.lowercased()
        var best: Int?
        for (index, haystack) in ([command.title] + [command.detail ?? ""] + command.keywords).enumerated() {
            let text = haystack.lowercased()
            guard !text.isEmpty else { continue }
            let weight = index == 0 ? 100 : 60
            var candidate: Int?
            if text.hasPrefix(needle) {
                candidate = weight + 30
            } else if text.split(separator: " ").contains(where: { $0.hasPrefix(needle) }) {
                candidate = weight + 20
            } else if text.contains(needle) {
                candidate = weight + 10
            } else if isSubsequence(needle, of: text) {
                candidate = weight
            }
            if let candidate, candidate > (best ?? Int.min) { best = candidate }
        }
        return best
    }

    private static func isSubsequence(_ needle: String, of text: String) -> Bool {
        var iterator = text.makeIterator()
        for character in needle {
            var found = false
            while let next = iterator.next() {
                if next == character {
                    found = true
                    break
                }
            }
            if !found { return false }
        }
        return true
    }
}
