import Foundation
import StudyBotKit
import Testing

/// §3.9: keystroke to glyph under 16ms. The editor restyles one paragraph per edit; this pins
/// the parser's cost so a whole-document pass stays far inside the budget even if a caller
/// ever asks for one.
@Suite("Live notes performance budget")
struct LiveNotesPerformanceTests {
    @Test("classifying a 400-line note takes well under a frame")
    func parseBudget() {
        let text = (0..<400).map { index -> String in
            switch index % 4 {
            case 0: return "- a bullet point about relations number \(index)"
            case 1: return "ASK: is this on the exam, question \(index)"
            case 2: return ""
            default: return "plain prose line \(index) with a few more words to make it realistic"
            }
        }.joined(separator: "\n")
        let start = ContinuousClock.now
        let lines = LiveNoteParser.lines(in: text)
        let questions = LiveNoteParser.questions(in: text)
        let elapsed = ContinuousClock.now - start
        #expect(lines.count == 400)
        #expect(questions.count == 100)
        #expect(elapsed < .milliseconds(16), "took \(elapsed)")
    }
}
