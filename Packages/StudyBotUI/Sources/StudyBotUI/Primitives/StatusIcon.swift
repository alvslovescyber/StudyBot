import StudyBotCore
import SwiftUI

/// The six status icons (spec §9 "Status icons"): drawn, not from a font. A 14pt circle with a
/// 1.5pt stroke: dashed for backlog, solid outline for todo, half-filled arc for drafting,
/// three-quarter arc for review, tick for submitted and graded. Every status also has a label
/// wherever it appears; colour never carries the meaning alone. `size` is a base value: the
/// icon sits beside text and scales with it, while its 1.5pt stroke does not.
public struct StatusIcon: View {
    private let status: AssignmentStatus
    private let size: CGFloat
    @Environment(\.sbScale) private var scale

    public init(_ status: AssignmentStatus, size: CGFloat = 14) {
        self.status = status
        self.size = size
    }

    public var body: some View {
        Canvas { context, canvasSize in
            let colour = SBColor.status(status)
            let stroke: CGFloat = 1.5
            let centre = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let radius = canvasSize.width / 2 - stroke
            let ring = Path(
                ellipseIn: CGRect(
                    x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2))

            switch status {
            case .backlog:
                context.stroke(
                    ring, with: .color(colour), style: StrokeStyle(lineWidth: stroke, dash: [2.5, 2.5]))
            case .todo:
                context.stroke(ring, with: .color(colour), lineWidth: stroke)
            case .drafting, .review:
                context.stroke(ring, with: .color(colour), lineWidth: stroke)
                let fraction: Double = status == .drafting ? 0.5 : 0.75
                let endDegrees: Double = -90 + 360 * fraction
                var arc = Path()
                arc.addArc(
                    center: centre, radius: radius / 2, startAngle: .degrees(-90),
                    endAngle: .degrees(endDegrees), clockwise: false)
                context.stroke(arc, with: .color(colour), lineWidth: radius)
            case .submitted, .graded:
                context.stroke(ring, with: .color(colour), lineWidth: stroke)
                var tick = Path()
                let unit = canvasSize.width / 14
                tick.move(to: CGPoint(x: centre.x - 3 * unit, y: centre.y))
                tick.addLine(to: CGPoint(x: centre.x - 1 * unit, y: centre.y + 2 * unit))
                tick.addLine(to: CGPoint(x: centre.x + 3 * unit, y: centre.y - 2 * unit))
                context.stroke(
                    tick, with: .color(colour),
                    style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
            }
        }
        .frame(width: scale(size), height: scale(size))
        .accessibilityLabel(StatusIcon.label(for: status))
    }

    /// The label that always accompanies the icon.
    public static func label(for status: AssignmentStatus) -> String {
        switch status {
        case .backlog: "Backlog"
        case .todo: "Todo"
        case .drafting: "Drafting"
        case .review: "In review"
        case .submitted: "Submitted"
        case .graded: "Graded"
        }
    }
}
