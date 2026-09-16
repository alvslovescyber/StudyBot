import Foundation
import StudyBotCore

/// "This term at a glance" (Today): four numbers, no charts. Sessions attended against held,
/// notes written, evidence logged, hours against the target so far. Derived from what is
/// actually in the store, so before induction every number is a true zero.
public struct TermGlance: Hashable, Sendable {
    public let sessionsHeld: Int
    public let sessionsAttended: Int
    public let notesWritten: Int
    public let evidenceLogged: Int
    public let hoursLogged: Double
    /// The target for the weeks of term elapsed so far, including the current one.
    public let hoursTarget: Double

    public init(
        term: Term, today: LocalDay, weekOfTerm: Int?, slots: [SessionSlot], sessions: [Session],
        evidence: [Evidence], hours: [OTJEntry], targetPerWeek: Double
    ) {
        let first = LocalDay(term.startDate)
        let last = LocalDay(term.endDate)
        func inTerm(_ day: LocalDay) -> Bool { day >= first && day <= last }
        let byID = Dictionary(sessions.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let hoursBySession = Set(hours.compactMap(\.sessionID))

        let held = slots.filter { inTerm($0.day) && $0.day <= today }
        sessionsHeld = held.count
        sessionsAttended = held.filter { slot in
            byID[slot.id]?.countsAsAttended == true || hoursBySession.contains(slot.id)
        }.count
        notesWritten = sessions.filter { inTerm(LocalDay($0.date)) && $0.hasNotes }.count
        evidenceLogged = evidence.filter { inTerm(LocalDay($0.date)) }.count
        hoursLogged = hours.filter { inTerm(LocalDay($0.date)) }.reduce(0) { $0 + $1.hours }
        hoursTarget = today >= first ? Double(max(weekOfTerm ?? 0, 0)) * targetPerWeek : 0
    }

    /// The four lines as label and value, in display order.
    public var lines: [(label: String, value: String)] {
        [
            ("Sessions attended", "\(sessionsAttended) of \(sessionsHeld)"),
            ("Notes written", "\(notesWritten)"),
            ("Evidence logged", "\(evidenceLogged)"),
            ("Hours", "\(TermGlance.hours(hoursLogged)) of \(TermGlance.hours(hoursTarget))"),
        ]
    }

    /// "4.5", "6", never "6.0".
    public static func hours(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)).locale(UKCalendar.locale))
    }
}
