import SwiftUI

/// A section header (spec §9 "Section headers"): `canvas` background, 12pt weight 600, the
/// count in `textTertiary` to its right, 1px rules top and bottom, 7×20 padding. They
/// separate; they do not decorate. Pass a collapse binding to make the header a toggle.
public struct SectionHeader: View {
    private let title: String
    private let count: Int?
    private let note: String?
    private let isCollapsed: Binding<Bool>?

    public init(_ title: String, count: Int? = nil, note: String? = nil, isCollapsed: Binding<Bool>? = nil) {
        self.title = title
        self.count = count
        self.note = note
        self.isCollapsed = isCollapsed
    }

    public var body: some View {
        if let isCollapsed {
            Button {
                isCollapsed.wrappedValue.toggle()
            } label: {
                label(collapsed: isCollapsed.wrappedValue)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isHeader)
            .accessibilityValue(isCollapsed.wrappedValue ? "collapsed" : "expanded")
        } else {
            label(collapsed: false).accessibilityAddTraits(.isHeader)
        }
    }

    private func label(collapsed: Bool) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(SBColor.textPrimary)
            if let count {
                Text("\(count)")
                    .font(.system(size: 12))
                    .foregroundStyle(SBColor.textTertiary)
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
            if let note {
                Text(note)
                    .font(.system(size: 11))
                    .foregroundStyle(SBColor.textTertiary)
            }
            if isCollapsed != nil {
                Image(systemName: collapsed ? "chevron.right" : "chevron.down")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(SBColor.textTertiary)
                    .frame(width: 12)
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(SBColor.canvas)
        .overlay(alignment: .top) { SBColor.border.frame(height: 1) }
        .overlay(alignment: .bottom) { SBColor.border.frame(height: 1) }
        .contentShape(Rectangle())
    }
}
