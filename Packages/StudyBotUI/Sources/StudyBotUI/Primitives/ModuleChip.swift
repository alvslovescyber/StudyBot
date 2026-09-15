import StudyBotCore
import SwiftUI

/// A module chip (spec §9 "Chips"): a 6px dot plus the short code in the module's colour,
/// 11pt weight 500. Module identity is one of the few places colour carries meaning. The text
/// scales with Dynamic Type; the dot is a graphic element and stays 6pt (§9).
public struct ModuleChip: View {
    private let module: Module?
    @Environment(\.sbScale) private var scale

    public init(_ module: Module?) {
        self.module = module
    }

    public var body: some View {
        if let module {
            HStack(spacing: scale(5)) {
                Circle()
                    .fill(SBColor.module(module.colour))
                    .frame(width: 6, height: 6)
                Text(module.shortCode)
                    .sbFont(11, weight: .medium)
                    .foregroundStyle(SBColor.module(module.colour))
                    .lineLimit(1)
            }
            .help("\(module.code) \(module.name)")
            .accessibilityLabel(module.name)
        } else {
            // No module yet: the calendar stubs. Nothing is drawn rather than an invented chip.
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityLabel("No module")
        }
    }
}
