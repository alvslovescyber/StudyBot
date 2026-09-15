import StudyBotCore
import SwiftUI

/// Colour tokens, verbatim from spec §9 "Colour". Light mode only in v1.
///
/// The rule: colour carries meaning or it does not appear. Module identity, status, overdue,
/// the accent on a primary action. Everything else is greyscale.
public enum SBColor {
    // Surfaces and text
    public static let canvas = Color(hex: "#FBFBFA")
    public static let surface = Color(hex: "#FFFFFF")
    public static let rowHover = Color(hex: "#F6F6F5")
    public static let border = Color(hex: "#E8E8E6")
    public static let borderStrong = Color(hex: "#D4D4D1")
    public static let textPrimary = Color(hex: "#1D1D1F")
    public static let textSecondary = Color(hex: "#6E6E73")
    public static let textTertiary = Color(hex: "#A1A1A6")
    public static let accent = Color(hex: "#5E6AD2")
    public static let accentSoft = Color(hex: "#EEF0FB")

    // Status and semantic, all muted to sit on a near-white canvas
    public static let statusBacklog = Color(hex: "#A1A1A6")
    public static let statusTodo = Color(hex: "#6E6E73")
    public static let statusDrafting = Color(hex: "#D9A441")
    public static let statusReview = Color(hex: "#5E6AD2")
    public static let statusDone = Color(hex: "#4A9E6B")
    /// Overdue and destructive actions. The only place red appears in normal use.
    public static let danger = Color(hex: "#C4483D")

    /// The colour for an assignment status.
    public static func status(_ status: AssignmentStatus) -> Color {
        switch status {
        case .backlog: statusBacklog
        case .todo: statusTodo
        case .drafting: statusDrafting
        case .review: statusReview
        case .submitted, .graded: statusDone
        }
    }

    /// The colour for a module, from its fixed palette entry.
    public static func module(_ colour: ModuleColour) -> Color {
        Color(hex: colour.hex)
    }

    /// The colour for a grade band (§6.2: distinction green, merit indigo, pass grey, fail red).
    public static func band(_ colour: BandColour) -> Color {
        switch colour {
        case .green: statusDone
        case .indigo: accent
        case .grey: textSecondary
        case .red: danger
        }
    }

    // Button materials (§9 "Component styling"). Named here so no view spells a hex.
    public enum Button {
        public static let secondaryTop = Color(hex: "#FFFFFF")
        public static let secondaryBottom = Color(hex: "#FAFAF9")
        public static let secondaryBorder = Color(hex: "#DEDEDB")
        public static let secondaryHover = Color(hex: "#F6F6F5")
        public static let secondaryPressed = Color(hex: "#F0F0EE")
        public static let primaryTop = Color(hex: "#6E79DC")
        public static let primaryMiddle = Color(hex: "#5E6AD2")
        public static let primaryBottom = Color(hex: "#5561C9")
        public static let primaryBorder = Color(hex: "#4F5ABD")
        public static let primaryPressedTop = Color(hex: "#4F5ABD")
        public static let primaryPressedBottom = Color(hex: "#4A55B8")
    }
}

extension Color {
    /// A colour from a `#RRGGBB` string. Tokens are the only callers; a malformed string
    /// gives black so the mistake is visible rather than silent.
    public init(hex: String) {
        var text = hex.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("#") { text.removeFirst() }
        guard text.count == 6, let value = UInt32(text, radix: 16) else {
            self = .black
            return
        }
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }
}
