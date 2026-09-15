import StudyBotUI
import SwiftUI

/// The app mark (§9 "The app mark"): the term strip. A hairline with tall marks for campus
/// blocks, short ticks for sessions and a hollow ring for a submission, in `accent` on white,
/// on a rounded square. Not a letter in a coloured square. The `.icns` derives from the same
/// drawing at larger sizes.
struct AppMark: View {
    var size: CGFloat = 18

    var body: some View {
        Canvas { context, canvasSize in
            let unit = canvasSize.width / 24
            let square = Path(
                roundedRect: CGRect(x: 1.5 * unit, y: 1.5 * unit, width: 21 * unit, height: 21 * unit),
                cornerRadius: 6 * unit, style: .continuous)
            context.fill(square, with: .color(SBColor.accent))

            var hairline = Path()
            hairline.move(to: CGPoint(x: 4.5 * unit, y: 12 * unit))
            hairline.addLine(to: CGPoint(x: 19.5 * unit, y: 12 * unit))
            context.stroke(hairline, with: .color(.white.opacity(0.45)), lineWidth: max(1 * unit, 0.75))

            var blocks = Path()
            for x in [6.0, 8.0, 10.0] {
                blocks.move(to: CGPoint(x: x * unit, y: 8.2 * unit))
                blocks.addLine(to: CGPoint(x: x * unit, y: 15.8 * unit))
            }
            context.stroke(
                blocks, with: .color(.white), style: StrokeStyle(lineWidth: 1.5 * unit, lineCap: .round))

            var ticks = Path()
            for x in [13.2, 15.4] {
                ticks.move(to: CGPoint(x: x * unit, y: 10.4 * unit))
                ticks.addLine(to: CGPoint(x: x * unit, y: 13.6 * unit))
            }
            context.stroke(
                ticks, with: .color(.white.opacity(0.6)),
                style: StrokeStyle(lineWidth: 1 * unit, lineCap: .round))

            let ring = Path(
                ellipseIn: CGRect(x: 16.3 * unit, y: 9.9 * unit, width: 4.2 * unit, height: 4.2 * unit))
            context.stroke(ring, with: .color(.white), lineWidth: 1.5 * unit)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
