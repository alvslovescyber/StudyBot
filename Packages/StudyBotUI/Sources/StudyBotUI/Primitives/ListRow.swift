import SwiftUI

/// A list row (spec §9 "List rows"): 38pt tall, horizontal padding 20, a 1px `border` rule
/// beneath, never a gap or a card. Hover fills `rowHover` instantly, with no transition,
/// because transitions on hover feel laggy at list speed. Selected fills `accentSoft`.
public struct ListRow<Content: View>: View {
    private let isSelected: Bool
    private let action: () -> Void
    private let content: Content

    @State private var isHovering = false

    public init(isSelected: Bool = false, action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.isSelected = isSelected
        self.action = action
        self.content = content()
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                content
            }
            .padding(.horizontal, SBSpacing.rowHorizontal)
            .frame(height: SBSpacing.rowHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill)
            .overlay(alignment: .bottom) {
                SBColor.border.frame(height: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }

    private var fill: Color {
        if isSelected { return SBColor.accentSoft }
        return isHovering ? SBColor.rowHover : SBColor.surface
    }
}
