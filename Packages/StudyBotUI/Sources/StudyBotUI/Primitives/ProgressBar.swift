import SwiftUI

/// A 4pt progress bar on a `border` track. Its width animates to a new value (spec §9
/// "Motion": 400ms ease-out) and never on first appearance: content that was already there
/// does not arrive.
public struct ProgressBar: View {
    private let value: Double
    private let width: CGFloat
    private let colour: Color

    public init(_ value: Double, width: CGFloat = 56, colour: Color = SBColor.accent) {
        self.value = min(max(value, 0), 1)
        self.width = width
        self.colour = colour
    }

    public var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(SBColor.border)
            Capsule().fill(colour).frame(width: width * value)
        }
        .frame(width: width, height: 4)
        .sbAnimation(SBMotion.progressBar, value: value)
        .accessibilityLabel("\(Int((value * 100).rounded())) percent")
    }
}
