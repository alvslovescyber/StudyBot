import SwiftUI

/// Typography, verbatim from spec §9 "Typography". SF Pro for interface, New York for
/// long-form reading, SF Mono for code, the palette input and columnar numbers. Never mono
/// for prose. No all-caps labels, no tracked-out eyebrow text.
public enum SBType {
    /// A role in the type scale: size, weight and tracking as the spec lists them.
    public struct Role: Sendable {
        public let size: CGFloat
        public let weight: Font.Weight
        /// Tracking in em; applied as points via `trackingPoints`.
        public let trackingEm: CGFloat

        public var font: Font { .system(size: size, weight: weight) }
        public var trackingPoints: CGFloat { size * trackingEm }
    }

    public static let display = Role(size: 28, weight: .semibold, trackingEm: -0.02)
    public static let title = Role(size: 20, weight: .semibold, trackingEm: -0.01)
    public static let section = Role(size: 15, weight: .medium, trackingEm: 0)
    /// 13 on macOS (15 on iOS, later).
    public static let body = Role(size: 13, weight: .regular, trackingEm: 0)
    public static let row = Role(size: 13, weight: .regular, trackingEm: 0)
    /// Row text when unread.
    public static let rowEmphasis = Role(size: 13, weight: .medium, trackingEm: 0)
    public static let meta = Role(size: 12, weight: .regular, trackingEm: 0)
    public static let micro = Role(size: 11, weight: .medium, trackingEm: 0.01)

    /// Long-form text: 17pt New York, line height 1.55, measure capped at 68 characters.
    public static let longForm = Font.system(size: 17, design: .serif)
    public static let longFormLineSpacing: CGFloat = 17 * 0.55
    public static let longFormMeasure: CGFloat = 68

    /// Live notes: 15pt SF Pro, line height 1.7, measure capped at 66 characters.
    public static let liveNotes = Font.system(size: 15)
    public static let liveNotesLineSpacing: CGFloat = 15 * 0.7
    public static let liveNotesMeasure: CGFloat = 66

    /// Code blocks, the palette input, columnar numbers.
    public static func mono(_ size: CGFloat = 12, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

extension View {
    /// Applies a type role: font and tracking together, so they cannot drift apart.
    public func sbType(_ role: SBType.Role) -> some View {
        font(role.font).tracking(role.trackingPoints)
    }
}
