import Foundation
import StudyBotCore
import Testing

@Suite("UKCalendar and LocalDay — §4 date and locale rules")
struct UKCalendarTests {
    @Test("the calendar is en-GB, Europe/London, Monday-first")
    func configuration() {
        #expect(UKCalendar.timeZone.identifier == "Europe/London")
        #expect(UKCalendar.locale.identifier == "en_GB")
        #expect(UKCalendar.calendar.firstWeekday == 2)
    }

    @Test("LocalDay parses ICS yyyyMMdd and ISO yyyy-MM-dd, and rejects nonsense")
    func parsing() {
        #expect(LocalDay(iso: "20260923") == LocalDay(year: 2026, month: 9, day: 23))
        #expect(LocalDay(iso: "2026-09-23") == LocalDay(year: 2026, month: 9, day: 23))
        #expect(LocalDay(iso: "2026-02-31") == nil)
        #expect(LocalDay(iso: "2026923") == nil)
        #expect(LocalDay(iso: "tomorrow") == nil)
        #expect(LocalDay(iso: "2026/09/23") == nil)
        #expect(LocalDay(year: 2026, month: 9, day: 23).isoString == "2026-09-23")
    }

    @Test("a LocalDay's Date is London midnight, in GMT and in BST")
    func londonMidnight() {
        // 23 September 2026 is in BST (UTC+1): midnight London is 23:00 UTC the day before.
        let bst = LocalDay(year: 2026, month: 9, day: 23).date
        #expect(bst.timeIntervalSince1970 == 1_790_118_000)
        // 15 January 2027 is GMT: midnight London is midnight UTC.
        let gmt = LocalDay(year: 2027, month: 1, day: 15).date
        #expect(gmt.timeIntervalSince1970 == 1_799_971_200)
        #expect(LocalDay(bst) == LocalDay(year: 2026, month: 9, day: 23))
        #expect(LocalDay(gmt) == LocalDay(year: 2027, month: 1, day: 15))
    }

    @Test("day arithmetic counts calendar days across the BST change, not 24-hour blocks")
    func acrossBSTChange() {
        // Clocks go back on Sunday 25 October 2026. The span 23 Oct → 27 Oct is 4 calendar days
        // even though it is 4 days and 1 hour of elapsed time.
        let before = LocalDay(year: 2026, month: 10, day: 23)
        let after = LocalDay(year: 2026, month: 10, day: 27)
        #expect(before.days(until: after) == 4)
        #expect(after.days(until: before) == -4)
        #expect(before.adding(days: 4) == after)
        #expect(after.date.timeIntervalSince(before.date) == 4 * 86_400 + 3_600)

        // Clocks go forward on Sunday 28 March 2027.
        let spring = LocalDay(year: 2027, month: 3, day: 26)
        #expect(spring.adding(days: 3) == LocalDay(year: 2027, month: 3, day: 29))
        #expect(spring.days(until: spring.adding(days: 3)) == 3)
    }

    @Test("an instant late on a London evening belongs to that London day, not the UTC day")
    func lateEveningIsSameLondonDay() {
        // London midnight on 23 Sep 2026 is 23:00 UTC on the 22nd. Half an hour either side of
        // it is 23:30 and 00:30 London time, which UTC would file under the same date.
        let midnight = LocalDay(year: 2026, month: 9, day: 23).date
        let lateEvening = midnight.addingTimeInterval(-1_800)
        let justAfterMidnight = midnight.addingTimeInterval(1_800)
        #expect(LocalDay(lateEvening) == LocalDay(year: 2026, month: 9, day: 22))
        #expect(LocalDay(justAfterMidnight) == LocalDay(year: 2026, month: 9, day: 23))
        #expect(!UKCalendar.isSameDay(lateEvening, justAfterMidnight))
    }

    @Test("weeks run Monday 00:00 to Sunday")
    func weeksStartMonday() {
        let wednesday = LocalDay(year: 2026, month: 9, day: 23)  // Wednesday
        #expect(wednesday.isoWeekday == 3)
        #expect(
            LocalDay(UKCalendar.startOfWeek(containing: wednesday.date))
                == LocalDay(year: 2026, month: 9, day: 21))
        #expect(
            LocalDay(UKCalendar.endOfWeek(containing: wednesday.date))
                == LocalDay(year: 2026, month: 9, day: 27))
        let sunday = LocalDay(year: 2026, month: 9, day: 27)
        #expect(sunday.isoWeekday == 7)
        #expect(sunday.isWeekend)
        #expect(
            LocalDay(UKCalendar.startOfWeek(containing: sunday.date))
                == LocalDay(year: 2026, month: 9, day: 21))
        #expect(!LocalDay(year: 2026, month: 9, day: 25).isWeekend)
        #expect(LocalDay(year: 2026, month: 9, day: 26).isWeekend)
    }

    @Test("a closed range of days enumerates inclusively")
    func rangeEnumeration() {
        let range = LocalDay(year: 2026, month: 9, day: 23)...LocalDay(year: 2026, month: 9, day: 24)
        #expect(range.days.map(\.isoString) == ["2026-09-23", "2026-09-24"])
        let single = LocalDay(year: 2026, month: 9, day: 22)...LocalDay(year: 2026, month: 9, day: 22)
        #expect(single.days.count == 1)
    }

    @Test("LocalDay encodes as a plain yyyy-MM-dd string")
    func codable() throws {
        let day = LocalDay(year: 2026, month: 10, day: 15)
        let data = try JSONEncoder().encode([day])
        #expect(try #require(String(data: data, encoding: .utf8)) == #"["2026-10-15"]"#)
        #expect(try JSONDecoder().decode([LocalDay].self, from: data) == [day])
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(LocalDay.self, from: Data(#""15/10/2026""#.utf8))
        }
    }
}
