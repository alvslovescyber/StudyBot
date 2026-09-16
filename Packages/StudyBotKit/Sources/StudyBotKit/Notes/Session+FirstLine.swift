import Foundation
import StudyBotCore

extension Session {
    /// The first line of the live notes with its bullet or `ASK:` marker stripped, for a
    /// one-line preview. Nil when there are no notes.
    public var firstNoteLine: String? {
        for line in liveNotes.split(omittingEmptySubsequences: true, whereSeparator: \.isNewline) {
            var text = line.trimmingCharacters(in: .whitespaces)
            if text.hasPrefix("- ") || text.hasPrefix("* ") || text.hasPrefix("• ") {
                text = String(text.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            }
            if let question = LiveNoteParser.questionText(of: text) {
                text = "ASK: " + question
            }
            if !text.isEmpty { return text }
        }
        return nil
    }
}
