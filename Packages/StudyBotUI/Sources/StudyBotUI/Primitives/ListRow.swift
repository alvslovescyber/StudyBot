import SwiftUI

/// A list row (spec §9 "List rows"): 38pt tall at the default text size, horizontal padding
/// 20, a 1px `border` rule beneath, never a gap or a card. The height scales with text and is
/// a minimum: at accessibility sizes a row may grow to two lines rather than clip (§9). Hover fills `rowHover` instantly, with no transition,
/// because transitions on hover feel laggy at list speed. Selected fills `accentSoft`.
public struct ListRow<Content: View>: View {
    private let isSelected: Bool
    private let action: () -> Void
    private let content: Content

    @State private var isHovering = false
    @Environment(\.sbScale) private var scale

    public init(isSelected: Bool = false, action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.isSelected = isSelected
        self.action = action
        self.content = content()
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: scale(11)) {
                content
            }
            .padding(.horizontal, scale(SBSpacing.rowHorizontal))
            .padding(.vertical, scale(4))
            .frame(minHeight: scale(SBSpacing.rowHeight))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill)
            .overlay(alignment: .bottom) {
                SBColor.border.frame(height: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        // Instant, by rule: no transition on hover or selection (§9 motion table).
        .animation(SBMotion.hover, value: isHovering)
        .animation(SBMotion.hover, value: isSelected)
    }

    private var fill: Color {
        if isSelected { return SBColor.accentSoft }
        return isHovering ? SBColor.rowHover : SBColor.surface
    }
}
