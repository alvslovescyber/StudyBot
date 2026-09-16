import SwiftUI

/// The one button (spec §9 "Buttons"). Two variants only, secondary and primary. No tertiary,
/// no ghost, no destructive variant: a destructive action is a secondary button that opens a
/// confirm.
///
/// Buttons are the one place the interface gets dimension. Everything else is flat. Nothing
/// moves: no lift on hover, no scale on press. The gradient and shadow change, that is all,
/// hover in 100ms and press in 60ms (§9 motion table).
/// Icons on primary buttons only, which is what makes primary read as primary at a glance
/// without colour doing all the work. `sparkles` means "this costs tokens" and appears on
/// every AI action and nowhere else.
public struct Btn: View {
    public enum Size: Sendable {
        case regular
        case small
    }

    private enum Variant {
        case primary(icon: String)
        case secondary
    }

    private let title: String
    private let variant: Variant
    private let size: Size
    private let action: () -> Void

    /// A primary button. The icon is required: a primary action always carries one (§9 table).
    public static func primary(
        _ title: String, icon: String, size: Size = .regular, action: @escaping () -> Void
    ) -> Btn {
        Btn(title: title, variant: .primary(icon: icon), size: size, action: action)
    }

    /// A secondary button. Text only, by rule.
    public static func secondary(_ title: String, size: Size = .regular, action: @escaping () -> Void) -> Btn
    {
        Btn(title: title, variant: .secondary, size: size, action: action)
    }

    private init(title: String, variant: Variant, size: Size, action: @escaping () -> Void) {
        self.title = title
        self.variant = variant
        self.size = size
        self.action = action
    }

    @Environment(\.sbScale) private var scale

    public var body: some View {
        Button(action: action) {
            HStack(spacing: scale(6)) {
                if case .primary(let icon) = variant {
                    Image(systemName: icon)
                        .sbFont(size == .small ? 12 : 13, weight: .medium)
                }
                Text(title)
            }
        }
        .buttonStyle(BtnStyle(isPrimary: isPrimary, size: size))
    }

    private var isPrimary: Bool {
        if case .primary = variant { return true }
        return false
    }
}

/// The material for both variants: exact values from the §9 component table.
struct BtnStyle: ButtonStyle {
    let isPrimary: Bool
    let size: Btn.Size

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.sbScale) private var scale
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .sbFont(size == .small ? 12 : 13, weight: isPrimary ? .medium : .medium)
            .foregroundStyle(foreground)
            .padding(.vertical, scale(size == .small ? 4 : 6))
            .padding(.horizontal, scale(horizontalPadding))
            .background(background(pressed: pressed))
            .overlay(border)
            .overlay(innerHighlight(pressed: pressed))
            .clipShape(RoundedRectangle(cornerRadius: SBRadius.button, style: .continuous))
            .modifier(BtnShadow(isPrimary: isPrimary, isEnabled: isEnabled, pressed: pressed))
            .contentShape(RoundedRectangle(cornerRadius: SBRadius.button, style: .continuous))
            .onHover { isHovering = $0 }
            .animation(SBMotion.buttonPress.animation, value: pressed)
            .animation(SBMotion.buttonHover.animation, value: isHovering)
    }

    private var horizontalPadding: CGFloat {
        if size == .small { return 11 }
        return isPrimary ? 14 : 13
    }

    private var foreground: Color {
        if !isEnabled { return SBColor.textTertiary }
        return isPrimary ? .white : SBColor.textPrimary
    }

    @ViewBuilder
    private func background(pressed: Bool) -> some View {
        if !isEnabled {
            // Disabled loses all depth: flat canvas, no gradient, no shadow, no highlight.
            SBColor.canvas
        } else if isPrimary {
            if pressed {
                LinearGradient(
                    colors: [SBColor.Button.primaryPressedTop, SBColor.Button.primaryPressedBottom],
                    startPoint: .top, endPoint: .bottom)
            } else {
                LinearGradient(
                    stops: [
                        .init(color: SBColor.Button.primaryTop, location: 0),
                        .init(color: SBColor.Button.primaryMiddle, location: 0.55),
                        .init(color: SBColor.Button.primaryBottom, location: 1),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                .brightness(isHovering ? 0.03 : 0)
            }
        } else if pressed {
            SBColor.Button.secondaryPressed
        } else if isHovering {
            SBColor.Button.secondaryHover
        } else {
            LinearGradient(
                colors: [SBColor.Button.secondaryTop, SBColor.Button.secondaryBottom],
                startPoint: .top, endPoint: .bottom)
        }
    }

    private var border: some View {
        RoundedRectangle(cornerRadius: SBRadius.button, style: .continuous)
            .strokeBorder(
                !isEnabled
                    ? SBColor.border
                    : isPrimary ? SBColor.Button.primaryBorder : SBColor.Button.secondaryBorder,
                lineWidth: 1)
    }

    /// The top-edge catch light that makes a primary button feel raised; gone when pressed.
    @ViewBuilder
    private func innerHighlight(pressed: Bool) -> some View {
        if isPrimary && isEnabled && !pressed {
            VStack(spacing: 0) {
                Color.white.opacity(0.20).frame(height: 1)
                Spacer(minLength: 0)
            }
            .padding(1)
        }
    }
}

/// Shadows per the table. On press the outer shadow collapses to an inset, which is what
/// communicates depression without the button moving.
private struct BtnShadow: ViewModifier {
    let isPrimary: Bool
    let isEnabled: Bool
    let pressed: Bool

    func body(content: Content) -> some View {
        if !isEnabled {
            content
        } else if pressed {
            content.overlay(
                RoundedRectangle(cornerRadius: SBRadius.button, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                (isPrimary ? Color(hex: "#141846") : .black).opacity(isPrimary ? 0.30 : 0.07),
                                .clear,
                            ],
                            startPoint: .top, endPoint: .center),
                        lineWidth: 2)
            )
        } else if isPrimary {
            content
                .shadow(color: Color(hex: "#1E235A").opacity(0.18), radius: 1, x: 0, y: 1)
                .shadow(color: SBColor.accent.opacity(0.22), radius: 3, x: 0, y: 2)
        } else {
            content.shadow(color: .black.opacity(0.05), radius: 0.75, x: 0, y: 1)
        }
    }
}
