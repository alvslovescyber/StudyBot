import StudyBotCore
import SwiftUI

/// A module chip (spec §9 "Chips"): a 6px dot plus the short code in the module's colour,
/// 11pt weight 500. Module identity is one of the few places colour carries meaning.
public struct ModuleChip: View {
    private let module: Module?

    public init(_ module: Module?) {
        self.module = module
    }

    public var body: some View {
        if let module {
            HStack(spacing: 5) {
                Circle()
                    .fill(SBColor.module(module.colour))
                    .frame(width: 6, height: 6)
                Text(module.shortCode)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(SBColor.module(module.colour))
                    .lineLimit(1)
            }
            .help("\(module.code) \(module.name)")
            .accessibilityLabel(module.name)
        } else {
            // No module yet: the calendar stubs. An em dash, not an invented chip.
            Text("—")
                .font(.system(size: 11))
                .foregroundStyle(SBColor.textTertiary)
                .accessibilityLabel("No module")
        }
    }
}
