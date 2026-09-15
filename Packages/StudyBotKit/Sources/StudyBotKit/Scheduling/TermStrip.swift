import Foundation
import StudyBotCore

/// The data behind Today's term strip (§6.1, §9 "Signature details"): the current term as one
/// line, with campus blocks, Monday sessions, submissions and today placed along it as
/// fractions of the term's length. The view draws; this decides. Also the spoken summary §16
/// asks for: "Term 1, week 4 of 13. Next submission in 31 days."
public struct TermStrip: Hashable, Sendable {
    public enum MarkKind: Hashable, Sendable {
        case block
        case session
        case submission
    }

    /// One mark on the line. `start` and `end` are fractions of the term, 0 at the first day
    /// and 1 at the last; a single day has `start == end`.
    public struct Mark: Hashable, Sendable {
        public let kind: MarkKind
        public let start: Double
        public let end: Double
        public let day: LocalDay
    }

    public let term: Term
    public let marks: [Mark]
    /// Where today falls, or nil when today is outside the term.
    public let todayPosition: Double?
    public let weekOfTerm: Int?
    public let weekCount: Int
    /// Days from today to the term's first day when the term has not started; nil otherwise.
    public let daysUntilStart: Int?
    /// Days to the next submission on or after today, in this term; nil if none remain.
    public let daysToNextSubmission: Int?

    /// The current term (or, between terms and before induction, the next one), or nil when the
    /// calendar has no term at or after `today`.
    public init?(calendar: TermCalendar, events: [ProgrammeEvent], submissionDates: [Date], today: LocalDay) {
        guard let term = calendar.term(containing: today) ?? calendar.nextTerm(after: today) else {
            return nil
        }
        self.term = term
        let first = LocalDay(term.startDate)
        let last = LocalDay(term.endDate)
        let span = max(first.days(until: last), 1)
        func position(_ day: LocalDay) -> Double {
            min(max(Double(first.days(until: day)) / Double(span), 0), 1)
        }
        let inTerm: (LocalDay) -> Bool = { $0 >= first && $0 <= last }

        var marks: [Mark] = []
        for block in calendar.blocks where block.end >= first && block.start <= last {
            let start = max(block.start, first)
            let end = min(block.end, last)
            marks.append(Mark(kind: .block, start: position(start), end: position(end), day: start))
        }
        for event in events where !event.isCancelled && event.kind == .online {
            let day = LocalDay(event.startDate)
            if inTerm(day) {
                marks.append(Mark(kind: .session, start: position(day), end: position(day), day: day))
            }
        }
        for date in Set(submissionDates.map(LocalDay.init)).sorted() where inTerm(date) {
            marks.append(Mark(kind: .submission, start: position(date), end: position(date), day: date))
        }
        self.marks = marks.sorted { ($0.start, $0.day) < ($1.start, $1.day) }

        todayPosition = inTerm(today) ? position(today) : nil
        weekOfTerm = calendar.weekOfTerm(today)
        weekCount = calendar.weekCount(of: term)
        daysUntilStart = today < first ? today.days(until: first) : nil
        daysToNextSubmission = submissionDates.map(LocalDay.init).filter { $0 >= today && inTerm($0) }.min()
            .map { today.days(until: $0) }
    }

    /// "Term 1", the strip's label.
    public var title: String { "Term \(term.number)" }

    /// The right-hand caption: "week 4 of 13", or "starts in 7 days" before the term.
    public var caption: String {
        if let daysUntilStart {
            switch daysUntilStart {
            case 0: return "starts today"
            case 1: return "starts tomorrow"
            default: return "starts in \(daysUntilStart) days"
            }
        }
        if let weekOfTerm { return "week \(weekOfTerm) of \(weekCount)" }
        return "\(weekCount) weeks"
    }

    /// The VoiceOver summary (§16): one sentence about where you are, one about what is next.
    public var summary: String {
        var parts = ["\(title), \(caption)."]
        switch daysToNextSubmission {
        case .some(0): parts.append("Submission due today.")
        case .some(1): parts.append("Next submission tomorrow.")
        case .some(let days): parts.append("Next submission in \(days) days.")
        case .none: parts.append("No submissions left this term.")
        }
        return parts.joined(separator: " ")
    }
}
