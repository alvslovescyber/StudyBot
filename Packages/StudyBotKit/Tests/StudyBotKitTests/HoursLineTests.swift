import Foundation
import StudyBotCore
import StudyBotKit
import Testing

@Suite("HoursLine — one typed line, no form")
struct HoursLineTests {
    @Test("the leading duration in every shape people type it")
    func durations() {
        let cases: [(String, Double)] = [
            ("2h", 2), ("2.5h", 2.5), ("2,5h", 2.5), ("2 hours", 2), ("1h30", 1.5), ("1h 30m", 1.5),
            ("90m", 1.5),
            ("45 min", 0.75), ("1:30", 1.5), ("3", 3), ("1hr", 1), ("2hrs reading", 2),
        ]
        for (text, hours) in cases {
            #expect(HoursLine.parse(text)?.hours == hours, "\(text)")
        }
    }

    @Test("the category is matched by prefix, defaults to self study, and the rest is the description")
    func categories() throws {
        let line = try #require(HoursLine.parse("2h project work — rewrote the pipeline checks"))
        #expect(line.category == .projectWork)
        #expect(line.description == "rewrote the pipeline checks")
        #expect(HoursLine.parse("1h lecture: networks")?.category == .lecture)
        #expect(HoursLine.parse("1h lecture: networks")?.description == "networks")
        #expect(HoursLine.parse("30m mentoring with Sam")?.category == .mentoring)
        #expect(HoursLine.parse("30m mentoring with Sam")?.description == "with Sam")
        #expect(HoursLine.parse("2h writing up the report")?.category == .writingUp)
        #expect(HoursLine.parse("2h writing up the report")?.description == "the report")
        #expect(HoursLine.parse("2h reading chapter 3")?.category == .research)
        #expect(HoursLine.parse("2h researcher interviews")?.category == .selfStudy, "a whole word only")
        #expect(HoursLine.parse("2h researcher interviews")?.description == "researcher interviews")
        #expect(HoursLine.parse("2h")?.description == "")
        #expect(HoursLine.parse("2h")?.category == .selfStudy)
    }

    @Test("no duration is no line, and the hint says what to type")
    func noDuration() {
        #expect(HoursLine.parse("project work all afternoon") == nil)
        #expect(HoursLine.parse("") == nil)
        #expect(HoursLine.parse("0h nothing") == nil)
        #expect(HoursLine.hint == "Start with how long: 2h, 90m or 1h30.")
        #expect(
            OTJCategory.projectWork.label == "Project work" && OTJCategory.selfStudy.label == "Self study")
    }
}
