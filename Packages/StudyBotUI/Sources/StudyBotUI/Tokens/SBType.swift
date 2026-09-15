import SwiftUI

/// Typography, from spec §9 "Typography". SF Pro for interface, New York for long-form
/// reading, SF Mono for code, the palette input and columnar numbers. Never mono for prose.
///
/// Every size here is a **base value at the default text size**, not an absolute (§9, §16).
/// Views never read a raw point size: they apply a role with `sbType(_:)` or a base size with
/// `sbFont(_:weight:design:)`, both of which multiply by `SBScale` from the environment, which
/// follows the Dynamic Type size. Layout that must stay in proportion to text (row heights,
/// icon frames, paddings, measures) goes through the same `SBScale`; graphic elements
/// (hairlines, module dots, the term strip's marks, the 56pt rail) do not.
public enum SBType {
    /// A role in the type scale: base size, weight and tracking as the spec lists them.
    public struct Role: Sendable {
        /// Base size at the default text size.
        public let size: CGFloat
        public let weight: Font.Weight
        /// Tracking in em; applied as points via `trackingPoints`.
        public let trackingEm: CGFloat

        /// The font at the default text size. Views use `sbType(_:)`, which scales.
        public var font: Font { .system(size: size, weight: weight) }
        public var trackingPoints: CGFloat { size * trackingEm }

        /// The font and tracking at a scale factor.
        public func font(at scale: SBScale) -> Font { .system(size: scale(size), weight: weight) }
        public func trackingPoints(at scale: SBScale) -> CGFloat { scale(size) * trackingEm }
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
    public static let longFormSize: CGFloat = 17
    public static let longForm = Font.system(size: longFormSize, design: .serif)
    public static let longFormLineSpacing: CGFloat = longFormSize * 0.55
    public static let longFormMeasure: CGFloat = 68

    /// Live notes: 15pt SF Pro, line height 1.7, measure capped at 66 characters.
    public static let liveNotesSize: CGFloat = 15
    public static let liveNotes = Font.system(size: liveNotesSize)
    public static let liveNotesLineSpacing: CGFloat = liveNotesSize * 0.7
    public static let liveNotesMeasure: CGFloat = 66

    /// Code blocks, the palette input, columnar numbers, at the default text size.
    public static func mono(_ size: CGFloat = 12, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    /// The scale factor for a Dynamic Type size. `large` is the default and 1. The ramp is
    /// the system's body-text ramp (17pt body at each size, divided by 17), so text here grows
    /// by the same proportion as text in any other app at the same setting.
    public static func scale(for size: DynamicTypeSize) -> CGFloat {
        (bodyPointSize[size] ?? 17) / 17
    }

    /// The system body size at each Dynamic Type size.
    private static let bodyPointSize: [DynamicTypeSize: CGFloat] = [
        .xSmall: 14, .small: 15, .medium: 16, .large: 17, .xLarge: 19, .xxLarge: 21, .xxxLarge: 23,
        .accessibility1: 28, .accessibility2: 33, .accessibility3: 40, .accessibility4: 47,
        .accessibility5: 53,
    ]
}

/// The one scale factor. `scale(13)` is a base value scaled to the current text size, rounded
/// to half a point so hairline-adjacent layout stays crisp.
public struct SBScale: Sendable, Equatable {
    public let factor: CGFloat

    public init(factor: CGFloat) {
        self.factor = factor
    }

    public init(_ size: DynamicTypeSize) {
        factor = SBType.scale(for: size)
    }

    public static let `default` = SBScale(factor: 1)

    public func callAsFunction(_ base: CGFloat) -> CGFloat {
        (base * factor * 2).rounded() / 2
    }

    /// Whether this is one of the accessibility sizes, where dense layouts may reflow.
    public var isAccessibility: Bool { factor >= SBType.scale(for: .accessibility1) }
}

extension EnvironmentValues {
    /// The scale that follows the Dynamic Type size. Read it with `@Environment(\.sbScale)`.
    public var sbScale: SBScale { SBScale(dynamicTypeSize) }
}

private struct SBTypeModifier: ViewModifier {
    @Environment(\.sbScale) private var scale
    let role: SBType.Role

    func body(content: Content) -> some View {
        content.font(role.font(at: scale)).tracking(role.trackingPoints(at: scale))
    }
}

private struct SBFontModifier: ViewModifier {
    @Environment(\.sbScale) private var scale
    let size: CGFloat
    let weight: Font.Weight
    let design: Font.Design

    func body(content: Content) -> some View {
        content.font(.system(size: scale(size), weight: weight, design: design))
    }
}

extension View {
    /// Applies a type role, scaled to the current text size: font and tracking together.
    public func sbType(_ role: SBType.Role) -> some View {
        modifier(SBTypeModifier(role: role))
    }

    /// A system font at a base size, scaled to the current text size. The only way a view
    /// may name a point size.
    public func sbFont(_ size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default)
        -> some View
    {
        modifier(SBFontModifier(size: size, weight: weight, design: design))
    }
}
