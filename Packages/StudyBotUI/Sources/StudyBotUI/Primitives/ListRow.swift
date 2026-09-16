import SwiftUI

/// A list row (spec §9 "List rows"): 38pt tall at the default text size, horizontal padding
/// 20, a 1px `border` rule beneath, never a gap or a card. The height scales with text and is
/// a minimum: at accessibility sizes a row may grow to two lines rather than clip (§9). Hover
/// fills `rowHover` instantly, with no transition, because transitions on hover feel laggy at
/// list speed. Selected fills `accentSoft`.
///
/// `actions` are the controls a hover reveals at the right of the row (§6.2: status,
/// priority, due date). They sit in an overlay beside the row's button, so their clicks are
/// theirs, and they appear the instant the cursor arrives. The content should leave room.
public struct ListRow<Content: View, Actions: View>: View {
    private let isSelected: Bool
    private let action: () -> Void
    private let content: Content
    private let actions: (Bool) -> Actions

    @State private var isHovering = false
    @Environment(\.sbScale) private var scale

    public init(
        isSelected: Bool = false, action: @escaping () -> Void, @ViewBuilder content: () -> Content,
        @ViewBuilder actions: @escaping (Bool) -> Actions
    ) {
        self.isSelected = isSelected
        self.action = action
        self.content = content()
        self.actions = actions
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
        .overlay(alignment: .trailing) {
            actions(isHovering)
                .padding(.trailing, scale(SBSpacing.rowHorizontal))
        }
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

extension ListRow where Actions == EmptyView {
    public init(isSelected: Bool = false, action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.init(isSelected: isSelected, action: action, content: content, actions: { _ in EmptyView() })
    }
}
