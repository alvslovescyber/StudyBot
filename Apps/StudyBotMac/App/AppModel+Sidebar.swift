import Foundation
import StudyBotCore
import StudyBotKit

/// The one number each sidebar section carries.
extension AppModel {
    func sidebarCount(for item: SidebarItem) -> Int {
        switch item {
        case .today:
            return notes?.allQuestions.count ?? 0
        case .assignments:
            guard let store = assignments, let term = store.currentTerm else { return 0 }
            return store.assignments.filter { $0.isIncomplete && $0.termID == term.id }.count
        case .modules:
            return notes?.allSessions.filter(\.hasNotes).count ?? 0
        case .revision:
            return revision?.queue(on: LocalDay(now())).count ?? 0
        case .portfolio:
            return evidence?.items.count ?? 0
        }
    }
}
