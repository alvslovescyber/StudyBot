import SwiftUI

/// The five sidebar sections (§5), with their SF Symbols (§9 "The sidebar": outline variants
/// only, never switched to `.fill` on selection) and ⌘1–⌘5.
enum SidebarItem: String, CaseIterable, Identifiable {
    case today
    case assignments
    case modules
    case revision
    case portfolio

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "Today"
        case .assignments: "Assignments"
        case .modules: "Modules & notes"
        case .revision: "Revision"
        case .portfolio: "Portfolio"
        }
    }

    var symbol: String {
        switch self {
        case .today: "sun.max"
        case .assignments: "checklist"
        case .modules: "book"
        case .revision: "rectangle.on.rectangle"
        case .portfolio: "checkmark.seal"
        }
    }

    var shortcutKey: KeyEquivalent {
        switch self {
        case .today: "1"
        case .assignments: "2"
        case .modules: "3"
        case .revision: "4"
        case .portfolio: "5"
        }
    }
}
