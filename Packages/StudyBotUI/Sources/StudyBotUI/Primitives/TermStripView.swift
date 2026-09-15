import StudyBotKit
import SwiftUI

/// The term strip (§9 "Signature details"): the whole term as one horizontal hairline, campus
/// blocks as tall accent marks, Monday sessions as small grey ticks, submissions as hollow amber
/// rings, today as a single vertical rule. No labels, no grid. Drawn, so it is one glance and
/// one accessibility element with the spoken summary §16 asks for.
public struct TermStripView: View {
    private let strip: TermStrip

    public init(_ strip: TermStrip) {
        self.strip = strip
    }

    public static let height: CGFloat = 28

    public var body: some View {
        Canvas { context, size in
            let midY = size.height / 2
            let inset: CGFloat = 4
            let width = size.width - inset * 2
            func x(_ fraction: Double) -> CGFloat { inset + CGFloat(fraction) * width }

            var line = Path()
            line.move(to: CGPoint(x: inset, y: midY))
            line.addLine(to: CGPoint(x: inset + width, y: midY))
            context.stroke(line, with: .color(SBColor.borderStrong), lineWidth: 1)

            for mark in strip.marks {
                switch mark.kind {
                case .block:
                    let left = x(mark.start)
                    let right = max(x(mark.end), left + 3)
                    let rect = CGRect(x: left - 1, y: midY - 8, width: right - left + 2, height: 16)
                    context.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(SBColor.accent))
                case .session:
                    let rect = CGRect(x: x(mark.start) - 0.5, y: midY - 3, width: 1, height: 6)
                    context.fill(Path(rect), with: .color(SBColor.textTertiary))
                case .submission:
                    let ring = Path(
                        ellipseIn: CGRect(x: x(mark.start) - 3.5, y: midY - 3.5, width: 7, height: 7))
                    context.fill(ring, with: .color(SBColor.surface))
                    context.stroke(ring, with: .color(SBColor.statusDrafting), lineWidth: 1.5)
                }
            }

            if let today = strip.todayPosition {
                let rect = CGRect(x: x(today) - 0.5, y: midY - 11, width: 1, height: 22)
                context.fill(Path(rect), with: .color(SBColor.textPrimary))
            }
        }
        .frame(height: TermStripView.height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(strip.summary)
    }
}
