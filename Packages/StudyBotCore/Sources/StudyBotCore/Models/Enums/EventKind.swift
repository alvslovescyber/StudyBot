/// The kind of a programme calendar event (spec §4). Drives colour and weight in every
/// calendar surface. Bank holidays and closures are shown greyed and never notify.
public enum EventKind: String, Codable, CaseIterable, Hashable, Sendable {
    case induction
    case onCampus
    case online
    case assignment
    case readingWeek
    case closure
    case bankHoliday
    case gateway
    case epa

    /// Whether the user is physically at the university on this day. Induction is a full
    /// day on campus, so it counts (confirmed with the user, 14 Sep 2026).
    public var isCampusDay: Bool {
        switch self {
        case .induction, .onCampus: true
        default: false
        }
    }

    /// Whether the day is a non-working day for `WorkingDays` (§4 "Dates, times and locale"):
    /// bank holidays, closures and campus days. Reading weeks are working days.
    public var blocksWorkingDay: Bool {
        switch self {
        case .bankHoliday, .closure, .induction, .onCampus: true
        case .online, .assignment, .readingWeek, .gateway, .epa: false
        }
    }

    /// Whether the event is a teaching session the user attends (on campus or online).
    public var isSession: Bool {
        switch self {
        case .induction, .onCampus, .online: true
        default: false
        }
    }

    /// Whether the event carries module codes in the calendar and therefore helps define
    /// which term it belongs to. Bank holidays and closures never do.
    public var isModuleBearingKind: Bool {
        switch self {
        case .bankHoliday, .closure: false
        default: true
        }
    }
}
