import AppKit
import SwiftUI

/// Motion, verbatim from spec §9 "Motion" (patches 7 and 8). Nothing moves under the cursor;
/// everything else may move in response. A hovered or pressed control changes colour and
/// material only. A row that changes status animates to its new group, a panel slides, a
/// count rolls, a menu springs: each is the app answering something the person did.
/// Animation on appearance, on scroll or on idle stays forbidden.
///
/// Every entry is a `Spec` with its duration and curve as plain numbers, so the values can
/// be pinned by a test and read in a review; `animation` is the SwiftUI value. Views apply
/// one with `sbAnimation(_:value:)` or `SBMotion.honouring`, both of which replace every
/// spring with a 100ms crossfade under Reduce Motion.
public enum SBMotion {
    public struct Spec: Sendable, Equatable {
        public enum Curve: Sendable, Equatable {
            case ease
            case easeOut
            case easeInOut
            /// A spring with `duration` as its response.
            case spring(damping: Double)
        }

        /// Seconds. A spring's response.
        public let duration: Double
        public let curve: Curve

        public init(_ duration: Double, _ curve: Curve) {
            self.duration = duration
            self.curve = curve
        }

        public var animation: Animation {
            switch curve {
            case .ease: .easeInOut(duration: duration)
            case .easeOut: .easeOut(duration: duration)
            case .easeInOut: .easeInOut(duration: duration)
            case .spring(let damping): .spring(response: duration, dampingFraction: damping)
            }
        }

        public var isSpring: Bool {
            if case .spring = curve { return true }
            return false
        }
    }

    // Under the cursor: nothing. Row hover and selection have no transition at all.
    // (`nil` passed to `.animation(_:value:)` is SwiftUI's "no animation".)
    public static let hover: Animation? = nil

    /// Button hover: the gradient brightens.
    public static let buttonHover = Spec(0.10, .ease)
    /// Button press: gradient darkens, shadow inverts. No transform.
    public static let buttonPress = Spec(0.06, .easeOut)
    /// A row that changes status moves from its old group to its new position.
    public static let rowMove = Spec(0.28, .spring(damping: 0.86))
    /// A deleted row collapses in height and its neighbours close up.
    public static let rowRemove = Spec(0.20, .easeOut)
    /// An inserted row's neighbours part and it fades in at full height.
    public static let rowInsert = Spec(0.24, .spring(damping: 0.86))
    /// Section collapse: height and opacity.
    public static let collapse = Spec(0.20, .ease)
    /// A count changes: the old digit slides up and out, the new slides in.
    public static let count = Spec(0.18, .easeInOut)
    /// The detail panel slides in from the right edge.
    public static let detailPanel = Spec(0.26, .spring(damping: 0.88))
    /// The command palette: opacity and scale 0.97 → 1.
    public static let palette = Spec(0.18, .spring(damping: 0.86))
    /// Popover or menu: scale 0.96 → 1 from its anchor point.
    public static let popover = Spec(0.14, .spring(damping: 0.86))
    /// A progress bar's width animates to its new value. Never on first appearance.
    public static let progressBar = Spec(0.40, .easeOut)
    /// Hours logged: the week bar grows to its new height.
    public static let hoursBar = Spec(0.50, .spring(damping: 0.8))
    /// Segmented control: the selected pill slides.
    public static let segment = Spec(0.22, .spring(damping: 0.9))
    /// Flashcard flip: 3D rotateY, content swaps at 90°.
    public static let flip = Spec(0.42, .easeInOut)
    /// Sidebar collapse: width.
    public static let sidebar = Spec(0.22, .spring(damping: 0.9))
    /// The sidebar's labels crossfade out over the first 80ms of the collapse.
    public static let sidebarLabel = Spec(0.08, .easeOut)
    /// The one orchestrated appearance: Today's blocks on first open of a session.
    public static let todayRise = Spec(0.32, .easeOut)
    /// What every spring becomes under Reduce Motion. The flip is disabled outright.
    public static let reduced = Spec(0.10, .easeInOut)

    /// The animation to use, honouring Reduce Motion.
    public static func honouring(_ reduceMotion: Bool, _ spec: Spec) -> Animation {
        reduceMotion ? reduced.animation : spec.animation
    }
}

private struct SBAnimationModifier<Value: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let spec: SBMotion.Spec
    let value: Value

    func body(content: Content) -> some View {
        content.animation(SBMotion.honouring(reduceMotion, spec), value: value)
    }
}

extension View {
    /// Animates changes to `value` with a §9 spec, honouring Reduce Motion. The only way a
    /// view should attach an animation.
    public func sbAnimation<Value: Equatable>(_ spec: SBMotion.Spec, value: Value) -> some View {
        modifier(SBAnimationModifier(spec: spec, value: value))
    }
}

/// `withAnimation` for a §9 spec, honouring Reduce Motion. Call sites that mutate state in
/// response to the user (a collapse toggle, a sidebar toggle) use this.
@MainActor
public func withSBAnimation<Result>(
    _ spec: SBMotion.Spec, reduceMotion: Bool = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
    _ body: () throws -> Result
) rethrows -> Result {
    try withAnimation(SBMotion.honouring(reduceMotion, spec), body)
}
