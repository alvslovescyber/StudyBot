import SwiftUI

/// Motion, verbatim from spec §9 "Motion". Motion is rare and every instance answers
/// something the person did. Nothing moves that the user did not move: state changes are
/// colour, material and opacity; geometry is fixed. Reduce Motion replaces every spring with
/// a 100ms crossfade.
public enum SBMotion {
    /// Sheets, palette, detail panels.
    public static let spring = Animation.spring(response: 0.32, dampingFraction: 0.85)
    /// The palette's 4pt rise and opacity fade.
    public static let paletteAppear = Animation.easeOut(duration: 0.14)
    /// Detail panel slide, 260ms spring.
    public static let detailPanel = Animation.spring(response: 0.26, dampingFraction: 0.88)
    /// Segmented control pill, sidebar width.
    public static let segment = Animation.spring(response: 0.22, dampingFraction: 0.9)
    /// Section collapse.
    public static let collapse = Animation.easeInOut(duration: 0.2)
    /// Progress bars, width from 0 on first appearance only.
    public static let progressBar = Animation.easeOut(duration: 0.5)
    /// Button material change. No transform.
    public static let buttonPress = Animation.easeOut(duration: 0.08)
    /// The one orchestrated moment: Today's four blocks, once per launch.
    public static let todayRise = Animation.easeOut(duration: 0.32)
    /// What every entry above becomes under Reduce Motion.
    public static let reduced = Animation.easeInOut(duration: 0.1)

    /// The animation to use, honouring Reduce Motion.
    public static func honouring(_ reduceMotion: Bool, _ animation: Animation) -> Animation {
        reduceMotion ? reduced : animation
    }
}
