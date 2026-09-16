import Foundation
import StudyBotKit
import Testing

@Suite("LiveNoteParser — bullets and ASK: lines without touching the text")
struct LiveNoteParserTests {
    @Test("questions are every ASK: line, marker and bullet stripped, blanks dropped")
    func questions() {
        let text = """
            - normalisation, 3NF
            - transitive dependency??
            - ASK: does 3NF matter for the assignment
            ask: what counts as a reference
            ASK:
            plain line
            ASK: last one
            """
        #expect(
            LiveNoteParser.questions(in: text) == [
                "does 3NF matter for the assignment", "what counts as a reference", "last one",
            ])
        #expect(LiveNoteParser.questions(in: "").isEmpty)
        #expect(LiveNoteParser.questionText(of: "  - ASK:  spaced  ") == "spaced")
        #expect(LiveNoteParser.questionText(of: "TASK: not a question") == nil)
    }

    @Test("lines are classified with the ranges the editor colours")
    func lines() {
        let text = "hello\n- bullet\n- ASK: q\nASK: bare\n"
        let lines = LiveNoteParser.lines(in: text)
        #expect(lines.map(\.kind) == [.plain, .bullet, .question, .question, .plain])
        #expect(lines[0].range == NSRange(location: 0, length: 5))
        #expect(lines[1].range == NSRange(location: 6, length: 8))
        #expect(lines[1].markerRange == NSRange(location: 6, length: 2))
        #expect(lines[2].markerRange == NSRange(location: 17, length: 4), "the ASK: after the bullet")
        #expect(lines[3].markerRange == NSRange(location: 24, length: 4))
        #expect(
            lines[4].range == NSRange(location: 34, length: 0), "the empty line after the trailing newline")
        #expect(LiveNoteParser.lines(in: "").map(\.kind) == [.plain])
    }

    @Test("a note without a trailing newline ends on its last line, and one line is one line")
    func noTrailingNewline() {
        let lines = LiveNoteParser.lines(in: "first\n- second")
        #expect(lines.map(\.kind) == [.plain, .bullet])
        #expect(lines[1].range == NSRange(location: 6, length: 8))
        #expect(LiveNoteParser.lines(in: "only").map(\.range) == [NSRange(location: 0, length: 4)])
        #expect(
            LiveNoteParser.lines(in: "\n").map(\.range) == [
                NSRange(location: 0, length: 0), NSRange(location: 1, length: 0),
            ])
        #expect(LiveNoteParser.lines(in: "a\n\nb").map(\.kind) == [.plain, .plain, .plain])
    }
}
