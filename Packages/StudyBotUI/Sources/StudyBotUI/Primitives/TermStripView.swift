import StudyBotCore
import StudyBotKit
import SwiftUI

/// The term strip (§9 "Signature details"): the whole term as one horizontal hairline, campus
/// blocks as tall accent marks, Monday sessions as small ticks (in their module's colour when
/// the calendar names one, §9 patch 9), submissions as hollow amber rings, today as a single
/// vertical rule. No labels on the line; hovering a mark says what it is. Drawn, so it is one
/// glance and one accessibility element with the spoken summary §16 asks for.
public struct TermStripView: View {
    private let strip: TermStrip
    @State private var hovered: TermStrip.Mark?

    public init(_ strip: TermStrip) {
        self.strip = strip
    }

    public static let height: CGFloat = 28
    /// Space above the line for the hover label.
    public static let labelHeight: CGFloat = 20
    private static let inset: CGFloat = 4

    public var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width - Self.inset * 2
            ZStack(alignment: .topLeading) {
                canvas
                    .frame(height: Self.height)
                    .offset(y: Self.labelHeight)
                if let hovered {
                    label(for: hovered, width: width)
                }
            }
            .frame(width: geometry.size.width, height: Self.height + Self.labelHeight, alignment: .topLeading)
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let point):
                    hovered = mark(nearest: point.x, width: width)
                case .ended:
                    hovered = nil
                }
            }
            // Instant, like every hover (§9).
            .animation(SBMotion.hover, value: hovered)
        }
        .frame(height: Self.height + Self.labelHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(strip.summary)
    }

    private func x(_ fraction: Double, width: CGFloat) -> CGFloat {
        Self.inset + CGFloat(fraction) * width
    }

    /// The mark under or within 6pt of `pointX`; a block counts across its whole width.
    private func mark(nearest pointX: CGFloat, width: CGFloat) -> TermStrip.Mark? {
        let tolerance: CGFloat = 6
        var best: (mark: TermStrip.Mark, distance: CGFloat)?
        for mark in strip.marks {
            let left = x(mark.start, width: width)
            let right = max(x(mark.end, width: width), left)
            let distance = pointX < left ? left - pointX : pointX > right ? pointX - right : 0
            guard distance <= tolerance else { continue }
            if best == nil || distance < best?.distance ?? .infinity { best = (mark, distance) }
        }
        return best?.mark
    }

    private func label(for mark: TermStrip.Mark, width: CGFloat) -> some View {
        Text(mark.label)
            .sbFont(11)
            .foregroundStyle(SBColor.textSecondary)
            .lineLimit(1)
            .fixedSize()
            .background(alignment: .center) {
                // Measured so the label stays inside the strip's bounds.
                GeometryReader { text in
                    Color.clear.preference(key: LabelWidthKey.self, value: text.size.width)
                }
            }
            .modifier(
                ClampedX(centre: x((mark.start + mark.end) / 2, width: width), bounds: width + Self.inset * 2)
            )
    }

    private var canvas: some View {
        Canvas { context, size in
            let midY = size.height / 2
            let width = size.width - Self.inset * 2
            func x(_ fraction: Double) -> CGFloat { Self.inset + CGFloat(fraction) * width }

            var line = Path()
            line.move(to: CGPoint(x: Self.inset, y: midY))
            line.addLine(to: CGPoint(x: Self.inset + width, y: midY))
            context.stroke(line, with: .color(SBColor.borderStrong), lineWidth: 1)

            for mark in strip.marks {
                let isHovered = mark == hovered
                switch mark.kind {
                case .block:
                    let left = x(mark.start)
                    let right = max(x(mark.end), left + 3)
                    let rect = CGRect(x: left - 1, y: midY - 8, width: right - left + 2, height: 16)
                    context.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(SBColor.accent))
                case .session:
                    let rect = CGRect(
                        x: x(mark.start) - 0.5, y: midY - (isHovered ? 5 : 3), width: 1,
                        height: isHovered ? 10 : 6)
                    let colour =
                        mark.moduleColour.map(SBColor.module)
                        ?? (isHovered ? SBColor.textSecondary : SBColor.textTertiary)
                    context.fill(Path(rect), with: .color(colour))
                case .submission:
                    let ring = Path(
                        ellipseIn: CGRect(x: x(mark.start) - 3.5, y: midY - 3.5, width: 7, height: 7))
                    context.fill(ring, with: .color(isHovered ? SBColor.statusDrafting : SBColor.surface))
                    context.stroke(ring, with: .color(SBColor.statusDrafting), lineWidth: 1.5)
                }
            }

            if let today = strip.todayPosition {
                let rect = CGRect(x: x(today) - 0.5, y: midY - 11, width: 1, height: 22)
                context.fill(Path(rect), with: .color(SBColor.textPrimary))
            }
        }
    }
}

private struct LabelWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

/// Positions a label centred on `centre`, pulled back inside `bounds` at either edge.
private struct ClampedX: ViewModifier {
    let centre: CGFloat
    let bounds: CGFloat
    @State private var width: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .onPreferenceChange(LabelWidthKey.self) { width = $0 }
            .offset(x: min(max(centre - width / 2, 0), max(bounds - width, 0)))
    }
}
