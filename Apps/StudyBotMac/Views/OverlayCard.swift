import StudyBotUI
import SwiftUI

/// A sheet drawn in the window (§9 "Cards and panels", "Motion"): a dimmed backdrop, a
/// centred card with the sheet radius and the palette's shadow, arriving with the palette's
/// spring. Escape or a click on the backdrop closes it. Used in place of `.sheet`, whose
/// AppKit slide is the slowest-feeling thing a button can trigger.
struct OverlayCard<Content: View>: View {
    let onClose: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)
            content()
                .background(SBColor.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: SBRadius.sheet, style: .continuous).strokeBorder(
                        SBColor.border)
                )
                .clipShape(RoundedRectangle(cornerRadius: SBRadius.sheet, style: .continuous))
                .sbShadow(SBShadow.palette)
                .onKeyPress(.escape) {
                    onClose()
                    return .handled
                }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .center)))
    }
}
