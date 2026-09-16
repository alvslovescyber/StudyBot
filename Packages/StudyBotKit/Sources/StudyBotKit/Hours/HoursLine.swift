import Foundation
import StudyBotCore

/// One typed line becomes an off-the-job entry: "2h project work: rewrote the pipeline
/// checks". The leading duration is required; the category is matched by prefix on the words
/// that follow and defaults to self study; whatever is left is the description. No form, no
/// dropdowns (Today, "One keystroke to log").
public struct HoursLine: Hashable, Sendable {
    public let hours: Double
    public let category: OTJCategory
    public let description: String

    /// What to type when the line has no duration.
    public static let hint = "Start with how long: 2h, 90m or 1h30."

    public static func parse(_ text: String) -> HoursLine? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let (hours, afterDuration) = duration(at: trimmed), hours > 0 else { return nil }
        let (category, rest) = categoryPrefix(of: afterDuration)
        return HoursLine(hours: hours, category: category ?? .selfStudy, description: description(from: rest))
    }

    // MARK: Duration

    private static let durationPattern = try? NSRegularExpression(
        pattern:
            #"^(\d+(?:[.,]\d+)?)(?::(\d{1,2}))?\s*(hours?|hrs?|h|minutes?|mins?|m)?(?:\s*(\d{1,2})\s*(?:minutes?|mins?|m)?)?(?=\s|$|[:,–—-])"#,
        options: [.caseInsensitive])

    /// Hours as a decimal and the text after the duration. "2h", "2.5h", "2 hours", "1h30",
    /// "1h 30m", "90m", "45 min", "1:30", or a bare number taken as hours.
    private static func duration(at text: String) -> (Double, String)? {
        guard let pattern = durationPattern,
            let match = pattern.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
        else { return nil }
        func group(_ index: Int) -> String? {
            guard let range = Range(match.range(at: index), in: text) else { return nil }
            return String(text[range])
        }
        guard let number = group(1).flatMap({ Double($0.replacingOccurrences(of: ",", with: ".")) }) else {
            return nil
        }
        let unit = group(3)?.lowercased() ?? "h"
        var hours: Double
        if unit.hasPrefix("m") {
            hours = number / 60
        } else {
            hours = number
            if let clockMinutes = group(2).flatMap(Double.init) {
                hours += clockMinutes / 60
            } else if let trailingMinutes = group(4).flatMap(Double.init) {
                hours += trailingMinutes / 60
            }
        }
        guard let end = Range(match.range, in: text)?.upperBound else { return nil }
        return (hours, String(text[end...]))
    }

    // MARK: Category

    /// The words that name each category, longest first so "project work" wins over "project".
    static let categoryWords: [(words: String, category: OTJCategory)] = [
        ("self study", .selfStudy), ("self-study", .selfStudy), ("project work", .projectWork),
        ("writing up", .writingUp), ("write up", .writingUp), ("write-up", .writingUp),
        ("lecture", .lecture), ("workshop", .workshop), ("study", .selfStudy), ("mentoring", .mentoring),
        ("mentor", .mentoring), ("shadowing", .shadowing), ("shadow", .shadowing), ("project", .projectWork),
        ("research", .research), ("reading", .research), ("writing", .writingUp), ("training", .training),
        ("course", .training),
    ]

    /// The category the text starts with, if any, and the text after it.
    private static func categoryPrefix(of text: String) -> (OTJCategory?, String) {
        let stripped = text.drop {
            $0.isWhitespace || $0 == ":" || $0 == "," || $0 == "-" || $0 == "–" || $0 == "—"
        }
        let lowered = stripped.lowercased()
        for (words, category) in categoryWords where lowered.hasPrefix(words) {
            let after = stripped.dropFirst(words.count)
            // A prefix match on a whole word only: "researcher" is a description, not research.
            if let next = after.first, next.isLetter { continue }
            return (category, String(after))
        }
        return (nil, String(stripped))
    }

    private static func description(from text: String) -> String {
        String(text.drop { $0.isWhitespace || $0 == ":" || $0 == "," || $0 == "-" || $0 == "–" || $0 == "—" })
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension OTJCategory {
    /// The category as the interface names it.
    public var label: String {
        switch self {
        case .lecture: "Lecture"
        case .workshop: "Workshop"
        case .selfStudy: "Self study"
        case .mentoring: "Mentoring"
        case .shadowing: "Shadowing"
        case .projectWork: "Project work"
        case .research: "Research"
        case .writingUp: "Writing up"
        case .training: "Training"
        }
    }
}
