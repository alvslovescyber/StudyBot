import Foundation
import Observation
import StudyBotCore

/// One day's plan and what the user did with it (§6.1): proposed until accepted or dismissed.
/// Accepting turns it into today's checklist; dismissing hides it until tomorrow and never
/// asks why. Local only, never synced: a plan is a suggestion about one Mac's day.
public struct DayPlan: Codable, Hashable, Sendable {
    public enum State: String, Codable, Sendable {
        case proposed
        case accepted
        case dismissed
    }

    public var day: LocalDay
    public var state: State
    public var items: [PlanItem]

    public init(day: LocalDay, state: State = .proposed, items: [PlanItem]) {
        self.day = day
        self.state = state
        self.items = items
    }
}

/// Where a day's plan is kept between launches.
public protocol PlanPersistence: Sendable {
    func load(day: LocalDay) -> DayPlan?
    func save(_ plan: DayPlan)
}

/// `UserDefaults`, one key per day. Old days are removed as new ones are written.
public struct UserDefaultsPlanPersistence: PlanPersistence, @unchecked Sendable {
    private let defaults: UserDefaults
    static let prefix = "studybot.plan."

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load(day: LocalDay) -> DayPlan? {
        guard let data = defaults.data(forKey: Self.prefix + day.isoString) else { return nil }
        return try? JSONDecoder().decode(DayPlan.self, from: data)
    }

    public func save(_ plan: DayPlan) {
        guard let data = try? JSONEncoder().encode(plan) else { return }
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(Self.prefix) {
            if key != Self.prefix + plan.day.isoString { defaults.removeObject(forKey: key) }
        }
        defaults.set(data, forKey: Self.prefix + plan.day.isoString)
    }
}

/// In memory, for tests and previews.
public final class InMemoryPlanPersistence: PlanPersistence, @unchecked Sendable {
    private let lock = NSLock()
    private var plans: [LocalDay: DayPlan] = [:]

    public init() {}

    public func load(day: LocalDay) -> DayPlan? {
        lock.withLock { plans[day] }
    }

    public func save(_ plan: DayPlan) {
        lock.withLock { plans[plan.day] = plan }
    }
}

@MainActor
@Observable
public final class PlanStore {
    public private(set) var plan: DayPlan?

    private let persistence: any PlanPersistence
    private let now: @Sendable () -> Date

    public init(persistence: any PlanPersistence, now: @escaping @Sendable () -> Date = { Date() }) {
        self.persistence = persistence
        self.now = now
    }

    private var today: LocalDay { LocalDay(now()) }

    /// Loads today's plan, or starts a fresh proposal from `items`. While the plan is still
    /// only proposed it follows the latest items; once accepted it is the day's checklist and
    /// stays put, ticks included; once dismissed it stays hidden until tomorrow.
    public func refresh(with items: [PlanItem]) {
        let day = today
        if plan?.day != day {
            plan = persistence.load(day: day)
        }
        guard let current = plan, current.day == day else {
            plan = DayPlan(day: day, items: items)
            return
        }
        if current.state == .proposed, current.items != items {
            plan = DayPlan(day: day, items: items)
        }
    }

    public var isProposed: Bool { plan?.state == .proposed }
    public var isAccepted: Bool { plan?.state == .accepted }
    public var isDismissed: Bool { plan?.state == .dismissed }

    /// Whether Today shows the plan at all: accepted, or proposed with something in it.
    public var isVisible: Bool {
        guard let plan else { return false }
        return plan.state == .accepted || (plan.state == .proposed && !plan.items.isEmpty)
    }

    public func accept() {
        guard var plan, plan.state == .proposed else { return }
        plan.state = .accepted
        commit(plan)
    }

    public func dismiss() {
        guard var plan, plan.state == .proposed else { return }
        plan.state = .dismissed
        commit(plan)
    }

    /// Ticks or unticks an item of the accepted checklist.
    public func toggle(_ itemID: String) {
        guard var plan, plan.state == .accepted, let index = plan.items.firstIndex(where: { $0.id == itemID })
        else { return }
        plan.items[index].isDone.toggle()
        commit(plan)
    }

    private func commit(_ plan: DayPlan) {
        self.plan = plan
        persistence.save(plan)
    }
}
