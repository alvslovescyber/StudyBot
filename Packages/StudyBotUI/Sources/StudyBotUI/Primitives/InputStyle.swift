import SwiftUI

/// Inputs and text areas (spec §9): `canvas` background, 1px `border`, radius 6, padding 9×11.
/// On focus the border becomes `accent` and nothing else changes: no glow, no ring, no lift.
public struct SBInputStyle: ViewModifier {
    @FocusState private var isFocused: Bool

    public func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .scrollContentBackground(.hidden)
            .font(.system(size: 13))
            .foregroundStyle(SBColor.textPrimary)
            .padding(.vertical, 9)
            .padding(.horizontal, 11)
            .background(SBColor.canvas)
            .overlay(
                RoundedRectangle(cornerRadius: SBRadius.control, style: .continuous)
                    .strokeBorder(isFocused ? SBColor.accent : SBColor.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: SBRadius.control, style: .continuous))
            .focused($isFocused)
    }
}

extension View {
    /// The one input look. Apply to `TextField` and `TextEditor`.
    public func sbInput() -> some View {
        modifier(SBInputStyle())
    }
}

/// A card or panel (spec §9): 1px `border`, radius 10, `surface`, no shadow and no gradient.
/// The opposite of a button, deliberately. If it does not float, it does not get a shadow.
public struct SBCardStyle: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .background(SBColor.surface)
            .overlay(
                RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous)
                    .strokeBorder(SBColor.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous))
    }
}

extension View {
    public func sbCard() -> some View {
        modifier(SBCardStyle())
    }
}
