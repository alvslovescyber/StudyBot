import Foundation
import StudyBotCore
import StudyBotKit
import Testing

@Suite("TermCalendar — §3.12 row 3")
struct TermCalendarTests {
    private func d(_ y: Int, _ m: Int, _ d: Int) -> LocalDay { RealCalendar.day(y, m, d) }

    private func calendar() throws -> TermCalendar {
        TermCalendar(events: try RealCalendar.events(), derivedAt: RealCalendar.importedAt)
    }

    @Test("nine terms, September 2026 to July 2029, with the derived boundaries")
    func nineTerms() throws {
        let terms = try calendar().terms
        let table = terms.map { "Y\($0.year)T\($0.number) \(LocalDay($0.startDate)) \(LocalDay($0.endDate))" }
        #expect(
            table == [
                "Y1T1 2026-09-22 2026-12-17",
                "Y1T2 2027-01-04 2027-04-01",
                "Y1T3 2027-04-19 2027-07-20",
                "Y2T1 2027-09-21 2027-12-16",
                "Y2T2 2028-01-11 2028-04-06",
                "Y2T3 2028-04-17 2028-07-13",
                "Y3T1 2028-09-18 2028-12-14",
                "Y3T2 2029-01-08 2029-04-05",
                "Y3T3 2029-04-18 2029-07-27",
            ])
        #expect(Set(terms.map(\.id)).count == 9)
        #expect(terms[0].id == Term.stableID(year: 1, number: 1))
    }

    @Test("terms never overlap and a later term starts after the previous one ends")
    func ordered() throws {
        let terms = try calendar().terms
        for (earlier, later) in zip(terms, terms.dropFirst()) {
            #expect(LocalDay(earlier.endDate) < LocalDay(later.startDate))
        }
    }

    @Test("the correct term for any date in the three years, and nil in the gaps")
    func termForDate() throws {
        let cal = try calendar()
        #expect(cal.term(containing: d(2026, 9, 22))?.shortLabel == "Y1 T1")
        #expect(cal.term(containing: d(2026, 10, 15))?.shortLabel == "Y1 T1")
        #expect(cal.term(containing: d(2026, 12, 17))?.shortLabel == "Y1 T1")
        #expect(cal.term(containing: d(2026, 12, 25)) == nil)  // Christmas gap
        #expect(cal.term(containing: d(2027, 1, 4))?.shortLabel == "Y1 T2")
        #expect(cal.term(containing: d(2027, 4, 10)) == nil)  // Easter gap
        #expect(cal.term(containing: d(2027, 4, 19))?.shortLabel == "Y1 T3")
        #expect(cal.term(containing: d(2027, 4, 26))?.shortLabel == "Y1 T3")  // session before Block 3
        #expect(cal.term(containing: d(2027, 7, 20))?.shortLabel == "Y1 T3")
        #expect(cal.term(containing: d(2027, 8, 20)) == nil)  // summer
        #expect(cal.term(containing: d(2028, 12, 14))?.shortLabel == "Y3 T1")
        #expect(cal.term(containing: d(2029, 4, 5))?.shortLabel == "Y3 T2")  // last Y3 T2 deadline
        #expect(cal.term(containing: d(2029, 4, 18))?.shortLabel == "Y3 T3")
        #expect(cal.term(containing: d(2029, 5, 1))?.shortLabel == "Y3 T3")  // inside the 35-day session gap
        #expect(cal.term(containing: d(2029, 7, 27))?.shortLabel == "Y3 T3")
        #expect(cal.term(containing: d(2029, 7, 28)) == nil)
        #expect(cal.term(containing: d(2026, 9, 1)) == nil)
    }

    @Test("behaviour in the gap between terms")
    func gaps() throws {
        let cal = try calendar()
        let summer = d(2027, 8, 20)
        #expect(cal.isGap(summer))
        #expect(cal.weekOfTerm(summer) == nil)
        #expect(cal.nextTerm(after: summer)?.shortLabel == "Y2 T1")
        #expect(cal.daysToNextBlock(from: summer) == 32)  // to Block 4 on 21 Sep 2027
        #expect(cal.nextTerm(after: d(2029, 8, 1)) == nil)
        #expect(cal.daysToNextBlock(from: d(2029, 8, 1)) == nil)
    }

    @Test("week of term counts Monday-to-Sunday weeks from the term's first week")
    func weekOfTerm() throws {
        let cal = try calendar()
        #expect(cal.weekOfTerm(d(2026, 9, 22)) == 1)  // Tuesday of week 1
        #expect(cal.weekOfTerm(d(2026, 9, 27)) == 1)  // Sunday of week 1
        #expect(cal.weekOfTerm(d(2026, 9, 28)) == 2)  // Monday of week 2
        #expect(cal.weekOfTerm(d(2026, 10, 15)) == 4)  // first deadline
        #expect(cal.weekOfTerm(d(2026, 12, 17)) == 13)
        let y1t1 = try #require(cal.terms.first)
        #expect(cal.weekCount(of: y1t1) == 13)
        #expect(cal.weekOfTerm(d(2027, 1, 4)) == 1)  // Block 2 Monday opens Y1 T2
    }

    @Test("blocks: induction merges with Block 1, and the §4A table's dates hold")
    func blocks() throws {
        let cal = try calendar()
        let table = cal.blocks.map { "\($0.number) \($0.start) \($0.end) \($0.dayCount)" }
        #expect(
            table == [
                "1 2026-09-22 2026-09-24 3",
                "2 2027-01-04 2027-01-06 3",
                "3 2027-05-04 2027-05-06 3",
                "4 2027-09-21 2027-09-22 2",
                "5 2028-01-11 2028-01-13 3",
                "6 2028-05-03 2028-05-05 3",
                "7 2028-09-18 2028-09-20 3",
                "8 2029-01-08 2029-01-10 3",
            ])
        #expect(cal.blocks[0].includesInduction)
        #expect(cal.blocks[0].eventIDs.count == 2)
        #expect(!cal.blocks[1].includesInduction)
    }

    @Test("days to the next block: 8 from 14 September 2026, 0 during a block")
    func daysToNextBlock() throws {
        let cal = try calendar()
        #expect(cal.daysToNextBlock(from: d(2026, 9, 14)) == 8)
        #expect(cal.daysToNextBlock(from: d(2026, 9, 22)) == 0)
        #expect(cal.daysToNextBlock(from: d(2026, 9, 24)) == 0)
        #expect(cal.daysToNextBlock(from: d(2026, 9, 25)) == 101)  // to 4 Jan 2027
        #expect(cal.block(containing: d(2026, 9, 23))?.number == 1)
        #expect(cal.block(containing: d(2026, 9, 25)) == nil)
        #expect(cal.currentOrNextBlock(from: d(2029, 1, 11)) == nil)
    }

    @Test("each term's module set matches the programme structure in §4")
    func moduleSets() throws {
        let cal = try calendar()
        let sets = cal.terms.map { cal.moduleCodes(in: $0).sorted() }
        #expect(sets[0] == ["COM1014DA", "COM1017DA", "COM1018DA"])
        #expect(sets[1] == ["COM1013DA", "COM1016DA", "COM1017DA"])
        #expect(sets[2] == ["COM1015DA", "COM1017DA", "COM1019DA"])
        #expect(sets[3] == ["COM2022DA", "COM2023DA", "COM2028DA"])
        #expect(sets[4] == ["COM2024DA", "COM2027DA", "COM2028DA"])
        #expect(sets[5] == ["COM2025DA", "COM2026DA", "COM2028DA"])
        #expect(sets[6] == ["COM3103DA", "COM3105DA", "COM3107DA", "COM3109DA", "COM3111DA", "COM3113DA"])
        #expect(sets[7] == sets[8])
        #expect(sets[7].contains("COM3104DA"))
    }

    @Test("a cancelled event is ignored when deriving terms and blocks")
    func cancelledIgnored() throws {
        var events = try RealCalendar.events()
        for index in events.indices where events[index].kind == .induction {
            events[index].cancelledAt = Date()
        }
        let cal = TermCalendar(events: events, derivedAt: RealCalendar.importedAt)
        #expect(cal.blocks[0].start == d(2026, 9, 23))
        #expect(!cal.blocks[0].includesInduction)
        #expect(LocalDay(cal.terms[0].startDate) == d(2026, 9, 23))
    }

    @Test("an empty calendar yields no terms and no blocks rather than crashing")
    func empty() {
        let cal = TermCalendar(events: [], derivedAt: RealCalendar.importedAt)
        #expect(cal.terms.isEmpty)
        #expect(cal.blocks.isEmpty)
        #expect(cal.term(containing: d(2026, 10, 1)) == nil)
        #expect(cal.daysToNextBlock(from: d(2026, 10, 1)) == nil)
    }
}
