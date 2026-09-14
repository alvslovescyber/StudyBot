import Foundation
import StudyBotCore

/// Which term, which week, days to the next block (spec §3.3, §4A). Everything is derived
/// from the imported programme events; no term date is typed anywhere.
///
/// **How terms are derived.** The spec says term dates come from "the first and last
/// programme event" but the calendar has no term markers, so the rule is:
///
/// 1. Events that carry module codes are grouped into runs sharing one module set. The
///    module set changes at eight points in the real file, and each run is a term. This is
///    what makes term 3 of years 1 and 2 begin at the April reading week rather than at the
///    May block, which the file confirms (the 19 April 2027 reading week already carries the
///    term-3 modules).
/// 2. Year 3 is the exception: the Synoptic Project spans terms 2 and 3, so its module set
///    changes only once. When a year has fewer than three runs, its last run is split at the
///    first teaching session after that year's Easter bank holidays, which is where term 3
///    begins in every other year (18 April 2029 in the real file). Spec §4A, open question 13.
/// 3. A term's start is its first event; its end is its last module-bearing event, extended by
///    any submission, Gateway or EPA event that falls before the next term begins. Bank
///    holidays, closures and un-attributed summer reading weeks never extend a term, so real
///    gaps exist between terms.
///
/// **Do not simplify this to a gap-based rule.** The final term has a 35-day gap inside it
/// (18 April to 23 May 2029) and a gap rule would split it in two.
public struct TermCalendar: Sendable {
    /// All terms, in date order. Nine for the real calendar.
    public let terms: [Term]
    /// Merged on-campus blocks, in date order.
    public let blocks: [CampusBlock]
    /// The module codes taught in each term, by term id.
    public let moduleCodesByTerm: [UUID: Set<String>]

    /// Derives terms and blocks from `events`. `now` stamps the derived `Term` records.
    public init(events: [ProgrammeEvent], derivedAt now: Date) {
        let derived = TermCalendar.deriveTerms(from: events, now: now)
        self.terms = derived.map(\.term)
        self.moduleCodesByTerm = Dictionary(
            uniqueKeysWithValues: derived.map { ($0.term.id, $0.moduleCodes) })
        self.blocks = CampusBlock.blocks(from: events)
    }

    // MARK: Terms

    /// The term containing `day`, or nil in a gap between terms or outside the programme.
    public func term(containing day: LocalDay) -> Term? {
        terms.first { LocalDay($0.startDate) <= day && day <= LocalDay($0.endDate) }
    }

    /// The first term starting after `day`. Nil after the programme ends.
    public func nextTerm(after day: LocalDay) -> Term? {
        terms.first { LocalDay($0.startDate) > day }
    }

    /// Whether `day` falls between two terms (or before the first, or after the last).
    public func isGap(_ day: LocalDay) -> Bool {
        term(containing: day) == nil
    }

    /// 1-based week of term for `day`, counting Monday-to-Sunday weeks from the week that
    /// contains the term's first day. Nil when `day` is not in a term.
    public func weekOfTerm(_ day: LocalDay) -> Int? {
        guard let term = term(containing: day) else { return nil }
        return weekNumber(of: day, from: LocalDay(term.startDate))
    }

    /// Total Monday-to-Sunday weeks a term spans.
    public func weekCount(of term: Term) -> Int {
        weekNumber(of: LocalDay(term.endDate), from: LocalDay(term.startDate))
    }

    private func weekNumber(of day: LocalDay, from start: LocalDay) -> Int {
        let weekStart = LocalDay(UKCalendar.startOfWeek(containing: start.date))
        let dayWeekStart = LocalDay(UKCalendar.startOfWeek(containing: day.date))
        return weekStart.days(until: dayWeekStart) / 7 + 1
    }

    /// The module codes taught in `term`.
    public func moduleCodes(in term: Term) -> Set<String> {
        moduleCodesByTerm[term.id] ?? []
    }

    // MARK: Blocks

    /// The block in progress on `day`, if any.
    public func block(containing day: LocalDay) -> CampusBlock? {
        blocks.first { $0.contains(day) }
    }

    /// The block in progress on `day`, or the next one to start. Nil after the last block.
    public func currentOrNextBlock(from day: LocalDay) -> CampusBlock? {
        blocks.first { $0.end >= day }
    }

    /// Days until the next block starts: 0 during a block, nil when no block remains.
    public func daysToNextBlock(from day: LocalDay) -> Int? {
        guard let block = currentOrNextBlock(from: day) else { return nil }
        return block.contains(day) ? 0 : day.days(until: block.start)
    }

    // MARK: Derivation

    struct DerivedTerm {
        var term: Term
        var moduleCodes: Set<String>
    }

    private struct Run {
        var codes: Set<String>
        var events: [ProgrammeEvent]
        var start: LocalDay { LocalDay(events[0].startDate) }
        var end: LocalDay { events.map { LocalDay($0.endDate) }.max() ?? start }
    }

    /// A run that has been placed in the programme as year `year`, term `number`.
    private struct PlacedRun {
        var year: Int
        var number: Int
        var run: Run
    }

    static func deriveTerms(from allEvents: [ProgrammeEvent], now: Date) -> [DerivedTerm] {
        let live = allEvents.filter { !$0.isCancelled }.sorted {
            ($0.startDate, $0.endDate) < ($1.startDate, $1.endDate)
        }
        let runs = moduleRuns(in: live)
        guard !runs.isEmpty else { return [] }
        let bankHolidays = live.filter { $0.kind == .bankHoliday }.map { LocalDay($0.startDate) }
        let placed = place(runs, bankHolidays: bankHolidays)
        let extenders = live.filter { [.assignment, .gateway, .epa].contains($0.kind) }

        return placed.enumerated().map { index, entry in
            let nextStart = index + 1 < placed.count ? placed[index + 1].run.start : nil
            let end = extendedEnd(of: entry.run, with: extenders, before: nextStart)
            let term = Term(
                sync: SyncMetadata.new(id: Term.stableID(year: entry.year, number: entry.number), at: now),
                year: entry.year, number: entry.number, startDate: entry.run.start.date, endDate: end.date)
            return DerivedTerm(term: term, moduleCodes: entry.run.codes)
        }
    }

    /// 1. Runs of module-bearing events sharing one module set, in date order.
    private static func moduleRuns(in live: [ProgrammeEvent]) -> [Run] {
        var runs: [Run] = []
        for event in live where event.kind.isModuleBearingKind && !event.moduleCodes.isEmpty {
            let codes = Set(event.moduleCodes)
            if var last = runs.last, last.codes == codes {
                last.events.append(event)
                runs[runs.count - 1] = last
            } else {
                runs.append(Run(codes: codes, events: [event]))
            }
        }
        return runs
    }

    /// 2. Group runs by programme year, split a short year at Easter, and number the terms.
    private static func place(_ runs: [Run], bankHolidays: [LocalDay]) -> [PlacedRun] {
        var byYear: [Int: [Run]] = [:]
        for run in runs {
            byYear[year(of: run), default: []].append(run)
        }
        var placed: [PlacedRun] = []
        for year in byYear.keys.sorted() {
            var yearRuns = byYear[year] ?? []
            if yearRuns.count < 3, let last = yearRuns.last,
                let (head, tail) = splitAtEaster(last, bankHolidays: bankHolidays)
            {
                yearRuns[yearRuns.count - 1] = head
                yearRuns.append(tail)
            }
            for (index, run) in yearRuns.enumerated() {
                placed.append(PlacedRun(year: year, number: index + 1, run: run))
            }
        }
        return placed
    }

    /// 3. A term ends at its last module-bearing event, or at the last submission, Gateway or
    /// EPA event that falls after it and before the next term starts.
    private static func extendedEnd(
        of run: Run, with extenders: [ProgrammeEvent], before nextStart: LocalDay?
    )
        -> LocalDay
    {
        var end = run.end
        for event in extenders {
            let eventStart = LocalDay(event.startDate)
            guard eventStart > end else { continue }
            if let nextStart, eventStart >= nextStart { continue }
            end = max(end, LocalDay(event.endDate))
        }
        return end
    }

    /// The programme year a run belongs to: the most common year digit among its module codes.
    private static func year(of run: Run) -> Int {
        var votes: [Int: Int] = [:]
        for code in run.codes {
            if let year = Module.year(fromCode: code) {
                votes[year, default: 0] += 1
            }
        }
        return votes.max { $0.value < $1.value || ($0.value == $1.value && $0.key > $1.key) }?.key ?? 0
    }

    /// Splits `run` at the first teaching session after the latest March/April bank holiday
    /// inside it. Nil when there is no such holiday or no session after it.
    private static func splitAtEaster(_ run: Run, bankHolidays: [LocalDay]) -> (Run, Run)? {
        let easter =
            bankHolidays
            .filter { $0 >= run.start && $0 <= run.end && (3...4).contains($0.month) }
            .max()
        guard let easter else { return nil }
        guard
            let splitIndex = run.events.firstIndex(where: {
                $0.kind.isSession && LocalDay($0.startDate) > easter
            }), splitIndex > 0
        else { return nil }
        let head = Run(codes: run.codes, events: Array(run.events[..<splitIndex]))
        let tail = Run(codes: run.codes, events: Array(run.events[splitIndex...]))
        return (head, tail)
    }
}
