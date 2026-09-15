import SwiftUI

/// Spacing, shape and depth, verbatim from spec §9 "Spacing, shape, depth".
public enum SBSpacing {
    /// 4pt base unit. Steps: 4, 8, 12, 16, 24, 32, 48.
    public static let unit: CGFloat = 4
    public static let x1: CGFloat = 4
    public static let x2: CGFloat = 8
    public static let x3: CGFloat = 12
    public static let x4: CGFloat = 16
    public static let x6: CGFloat = 24
    public static let x8: CGFloat = 32
    public static let x12: CGFloat = 48

    /// Padding inside rows.
    public static let rowInset: CGFloat = 16
    /// Padding around content regions.
    public static let region: CGFloat = 24
    /// Padding at the outer edge of a detail view on macOS.
    public static let detailOuter: CGFloat = 32

    /// List rows: 38pt tall on macOS, horizontal padding 20.
    public static let rowHeight: CGFloat = 38
    public static let rowHorizontal: CGFloat = 20
    /// Sidebar rows: 28pt, 8pt horizontal inset, 6pt between groups.
    public static let sidebarRowHeight: CGFloat = 28
    public static let sidebarInset: CGFloat = 8
    public static let sidebarGroupGap: CGFloat = 6
    /// Sidebar widths: 228pt expanded, 56pt as an icon rail.
    public static let sidebarWidth: CGFloat = 228
    public static let sidebarRailWidth: CGFloat = 56
}

public enum SBRadius {
    /// Controls and chips.
    public static let control: CGFloat = 6
    /// Buttons, from the component table.
    public static let button: CGFloat = 7
    /// Cards and popovers.
    public static let card: CGFloat = 10
    /// Sheets.
    public static let sheet: CGFloat = 14
    /// Pills and tags.
    public static let pill: CGFloat = 999
}

/// Shadows are for genuine layers only: popovers, sheets, the palette, the flashcard.
/// Rows and cards use borders, not shadows. Buttons have their own, in `Btn`.
public enum SBShadow {
    public struct Spec: Sendable {
        public let color: Color
        public let radius: CGFloat
        public let x: CGFloat
        public let y: CGFloat
    }

    /// Popovers and sheets: y 4, blur 16, black 6%.
    public static let layer = Spec(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
    /// The command palette.
    public static let palette = Spec(color: .black.opacity(0.16), radius: 20, x: 0, y: 12)
    /// The flashcard.
    public static let flashcard = Spec(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
}

extension View {
    public func sbShadow(_ spec: SBShadow.Spec) -> some View {
        shadow(color: spec.color, radius: spec.radius, x: spec.x, y: spec.y)
    }
}
