import AppKit
import StudyBotCore
import SwiftUI

/// Colour tokens. The light values are verbatim from spec §9 "Colour". The spec scoped v1 to
/// light mode; the dark values are the same palette re-pitched for a dark canvas so the app
/// follows the system appearance rather than glaring in a dark room. Same rules apply: colour
/// carries meaning or it does not appear.
public enum SBColor {
    // Surfaces and text
    public static let canvas = Color.adaptive(light: "#FBFBFA", dark: "#1A1A1C")
    public static let surface = Color.adaptive(light: "#FFFFFF", dark: "#202023")
    public static let rowHover = Color.adaptive(light: "#F6F6F5", dark: "#27272B")
    public static let border = Color.adaptive(light: "#E8E8E6", dark: "#2E2E33")
    public static let borderStrong = Color.adaptive(light: "#D4D4D1", dark: "#3C3C42")
    public static let textPrimary = Color.adaptive(light: "#1D1D1F", dark: "#EDEDEF")
    public static let textSecondary = Color.adaptive(light: "#6E6E73", dark: "#9C9CA3")
    public static let textTertiary = Color.adaptive(light: "#A1A1A6", dark: "#6E6E75")
    public static let accent = Color.adaptive(light: "#5E6AD2", dark: "#7B86E2")
    public static let accentSoft = Color.adaptive(light: "#EEF0FB", dark: "#272B45")

    // Status and semantic, all muted to sit on the canvas without shouting
    public static let statusBacklog = Color.adaptive(light: "#A1A1A6", dark: "#6E6E75")
    public static let statusTodo = Color.adaptive(light: "#6E6E73", dark: "#9C9CA3")
    public static let statusDrafting = Color.adaptive(light: "#D9A441", dark: "#E0B458")
    public static let statusReview = Color.adaptive(light: "#5E6AD2", dark: "#7B86E2")
    public static let statusDone = Color.adaptive(light: "#4A9E6B", dark: "#5FB57F")
    /// Overdue and destructive actions. The only place red appears in normal use.
    public static let danger = Color.adaptive(light: "#C4483D", dark: "#E0655B")

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

    /// The colour for a module, from its fixed palette entry. Mid-tone by design, so the same
    /// value reads in both appearances.
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
        public static let secondaryTop = Color.adaptive(light: "#FFFFFF", dark: "#2C2C30")
        public static let secondaryBottom = Color.adaptive(light: "#FAFAF9", dark: "#26262A")
        public static let secondaryBorder = Color.adaptive(light: "#DEDEDB", dark: "#3C3C42")
        public static let secondaryHover = Color.adaptive(light: "#F6F6F5", dark: "#313136")
        public static let secondaryPressed = Color.adaptive(light: "#F0F0EE", dark: "#222226")
        public static let primaryTop = Color(hex: "#6E79DC")
        public static let primaryMiddle = Color(hex: "#5E6AD2")
        public static let primaryBottom = Color(hex: "#5561C9")
        public static let primaryBorder = Color(hex: "#4F5ABD")
        public static let primaryPressedTop = Color(hex: "#4F5ABD")
        public static let primaryPressedBottom = Color(hex: "#4A55B8")
    }

    /// The light and dark hex values behind an adaptive token, for tests and documentation.
    public struct Pair: Sendable, Equatable {
        public let light: String
        public let dark: String
    }
}

extension Color {
    /// A colour from a `#RRGGBB` string. Tokens are the only callers; a malformed string
    /// gives black so the mistake is visible rather than silent.
    public init(hex: String) {
        guard let components = Color.components(hex: hex) else {
            self = .black
            return
        }
        self.init(.sRGB, red: components.red, green: components.green, blue: components.blue, opacity: 1)
    }

    /// A colour that follows the system appearance: one hex for light, one for dark.
    public static func adaptive(light: String, dark: String) -> Color {
        let lightColor = NSColor(hex: light)
        let darkColor = NSColor(hex: dark)
        return Color(
            nsColor: NSColor(name: nil) { appearance in
                appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? darkColor : lightColor
            })
    }

    /// sRGB channels in 0...1.
    struct RGB {
        let red: Double
        let green: Double
        let blue: Double
    }

    static func components(hex: String) -> RGB? {
        var text = hex.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("#") { text.removeFirst() }
        guard text.count == 6, let value = UInt32(text, radix: 16) else { return nil }
        return RGB(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255)
    }
}

extension NSColor {
    convenience init(hex: String) {
        let components = Color.components(hex: hex) ?? Color.RGB(red: 0, green: 0, blue: 0)
        self.init(srgbRed: components.red, green: components.green, blue: components.blue, alpha: 1)
    }
}
