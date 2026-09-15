import SwiftUI

/// A 4pt progress bar on a `border` track. Width animates from 0 on first appearance only
/// (spec §9 "Motion": 500ms ease-out); afterwards it changes without animation. The only
/// thing here that ever moves, and it moves once.
public struct ProgressBar: View {
    private let value: Double
    private let width: CGFloat
    private let colour: Color

    @State private var shown: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(_ value: Double, width: CGFloat = 56, colour: Color = SBColor.accent) {
        self.value = min(max(value, 0), 1)
        self.width = width
        self.colour = colour
    }

    public var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(SBColor.border)
            Capsule().fill(colour).frame(width: width * shown)
        }
        .frame(width: width, height: 4)
        .onAppear {
            withAnimation(reduceMotion ? nil : SBMotion.progressBar) {
                shown = value
            }
        }
        .onChange(of: value) { _, newValue in
            shown = newValue
        }
        .accessibilityLabel("\(Int((value * 100).rounded())) percent")
    }
}
