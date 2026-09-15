import Foundation

/// The light structure live notes carry (§6.3): a line starting `- ` is a bullet, a line
/// starting `ASK:` is a question. Parsing never changes the text; it only says what each line
/// is, so the editor can colour it and the questions list can collect it.
public enum LiveNoteParser {
    public enum LineKind: Hashable, Sendable {
        case plain
        case bullet
        case question
    }

    /// One line of the note with its kind and its UTF-16 range, for attributed styling.
    public struct Line: Hashable, Sendable {
        public let kind: LineKind
        public let range: NSRange
        /// For a bullet, the range of the leading `- `; for a question, of the `ASK:` marker.
        public let markerRange: NSRange?
    }

    /// The marker a question line starts with. Case-insensitive, and allowed after a bullet.
    public static let questionMarker = "ASK:"

    /// Every line, in order, with its kind.
    public static func lines(in text: String) -> [Line] {
        let nsText = text as NSString
        var result: [Line] = []
        var location = 0
        while location <= nsText.length {
            let lineRange = nsText.lineRange(for: NSRange(location: location, length: 0))
            var contentLength = lineRange.length
            if contentLength > 0, let last = Unicode.Scalar(nsText.character(at: NSMaxRange(lineRange) - 1)),
                CharacterSet.newlines.contains(last)
            {
                contentLength -= 1
            }
            let content = nsText.substring(with: NSRange(location: lineRange.location, length: contentLength))
            result.append(classify(content, at: lineRange.location, length: contentLength))
            if lineRange.length == 0 { break }
            location = NSMaxRange(lineRange)
            if location == nsText.length, !text.isEmpty, text.hasSuffix("\n") {
                // A trailing newline means an empty last line the caret can sit on.
                result.append(
                    Line(kind: .plain, range: NSRange(location: location, length: 0), markerRange: nil))
                break
            }
        }
        return result
    }

    /// The questions in the note: every `ASK:` line, marker and bullet stripped, blank ones
    /// dropped. Order is the order in the note.
    public static func questions(in text: String) -> [String] {
        text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).compactMap { line in
            guard let question = questionText(of: String(line)) else { return nil }
            return question.isEmpty ? nil : question
        }
    }

    /// The text after `ASK:` if this is a question line, trimmed; nil otherwise.
    public static func questionText(of line: String) -> String? {
        var body = Substring(line.drop(while: \.isWhitespace))
        if body.hasPrefix("- ") { body = body.dropFirst(2).drop(while: \.isWhitespace) }
        guard body.count >= questionMarker.count,
            body.prefix(questionMarker.count).lowercased() == questionMarker.lowercased()
        else { return nil }
        return String(body.dropFirst(questionMarker.count)).trimmingCharacters(in: .whitespaces)
    }

    private static func classify(_ content: String, at location: Int, length: Int) -> Line {
        let range = NSRange(location: location, length: length)
        let nsContent = content as NSString
        let leading = content.prefix(while: \.isWhitespace).utf16.count
        var cursor = leading
        var isBullet = false
        if nsContent.length >= cursor + 2,
            nsContent.substring(with: NSRange(location: cursor, length: 2)) == "- "
        {
            isBullet = true
            cursor += 2
            while cursor < nsContent.length, let scalar = Unicode.Scalar(nsContent.character(at: cursor)),
                CharacterSet.whitespaces.contains(scalar)
            {
                cursor += 1
            }
        }
        let markerLength = (questionMarker as NSString).length
        if nsContent.length >= cursor + markerLength,
            nsContent.substring(with: NSRange(location: cursor, length: markerLength)).lowercased()
                == questionMarker.lowercased()
        {
            return Line(
                kind: .question, range: range,
                markerRange: NSRange(location: location + cursor, length: markerLength))
        }
        if isBullet {
            return Line(
                kind: .bullet, range: range, markerRange: NSRange(location: location + leading, length: 2))
        }
        return Line(kind: .plain, range: range, markerRange: nil)
    }
}
