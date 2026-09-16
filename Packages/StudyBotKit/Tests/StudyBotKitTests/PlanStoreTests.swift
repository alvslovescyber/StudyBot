import Foundation
import StudyBotCore
import StudyBotKit
import Testing

@MainActor
@Suite("PlanStore — proposed, accepted, dismissed, and a new day")
struct PlanStoreTests {
    private nonisolated static let day1 = RealCalendar.day(2026, 10, 6).date.addingTimeInterval(9 * 3_600)
    private nonisolated static let items = [
        PlanItem(id: "a", title: "Draft section 2", minutes: 60),
        PlanItem(id: "b", title: "Review notes", minutes: 30),
    ]

    @Test("a proposal follows the latest items until it is accepted, then it is the day's checklist")
    func proposeAndAccept() {
        let persistence = InMemoryPlanPersistence()
        let store = PlanStore(persistence: persistence, now: { Self.day1 })
        store.refresh(with: Self.items)
        #expect(store.isProposed && store.isVisible)
        #expect(store.plan?.items == Self.items)

        let fewer = [Self.items[0]]
        store.refresh(with: fewer)
        #expect(store.plan?.items == fewer, "still proposed, so it follows")

        store.accept()
        #expect(store.isAccepted)
        store.refresh(with: Self.items)
        #expect(store.plan?.items == fewer, "accepted: the checklist stays put")

        store.toggle("a")
        #expect(store.plan?.items.first?.isDone == true)
        store.toggle("missing")
        #expect(store.plan?.items.first?.isDone == true, "an unknown id changes nothing")

        let reopened = PlanStore(persistence: persistence, now: { Self.day1 })
        reopened.refresh(with: Self.items)
        #expect(reopened.isAccepted && reopened.plan?.items.first?.isDone == true, "survives a relaunch")
    }

    @Test("dismiss hides the plan for the day and asks nothing; tomorrow starts fresh")
    func dismiss() {
        let persistence = InMemoryPlanPersistence()
        let store = PlanStore(persistence: persistence, now: { Self.day1 })
        store.refresh(with: Self.items)
        store.dismiss()
        #expect(store.isDismissed && !store.isVisible)
        store.refresh(with: Self.items)
        #expect(store.isDismissed, "a refresh does not resurrect it")
        store.toggle("a")
        #expect(store.plan?.items.first?.isDone == false, "nothing to tick on a dismissed plan")

        let tomorrow = PlanStore(persistence: persistence, now: { Self.day1.addingTimeInterval(86_400) })
        tomorrow.refresh(with: Self.items)
        #expect(tomorrow.isProposed && tomorrow.plan?.items == Self.items)
    }

    @Test("an empty proposal is not shown, and UserDefaults keeps one day only")
    func emptyAndDefaults() throws {
        let suite = "studybot.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let persistence = UserDefaultsPlanPersistence(defaults: defaults)
        let store = PlanStore(persistence: persistence, now: { Self.day1 })
        store.refresh(with: [])
        #expect(store.isProposed && !store.isVisible)
        store.refresh(with: Self.items)
        store.accept()
        let next = PlanStore(persistence: persistence, now: { Self.day1.addingTimeInterval(86_400) })
        next.refresh(with: Self.items)
        next.accept()
        let keys = defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix("studybot.plan.") }
        #expect(keys.count == 1, "yesterday's plan is gone once today's is written")
        #expect(persistence.load(day: LocalDay(Self.day1)) == nil)
    }
}
