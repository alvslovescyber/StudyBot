import SwiftUI

/// A metadata chip (spec §9 "Chips"): radius 6 with a 1px border, 12pt. In a detail panel's
/// read mode it is display text; in edit mode the same shape becomes a control with a stronger
/// border. No pill radius here: that is `Tag`.
public struct Chip<Leading: View>: View {
    private let text: String
    private let isEditable: Bool
    private let leading: Leading
    @Environment(\.sbScale) private var scale

    public init(_ text: String, isEditable: Bool = false, @ViewBuilder leading: () -> Leading) {
        self.text = text
        self.isEditable = isEditable
        self.leading = leading()
    }

    public var body: some View {
        HStack(spacing: scale(6)) {
            leading
            Text(text)
                .sbFont(12)
                .lineLimit(1)
            if isEditable {
                Image(systemName: "chevron.down")
                    .sbFont(9, weight: .medium)
                    .foregroundStyle(SBColor.textTertiary)
            }
        }
        .foregroundStyle(isEditable ? SBColor.textPrimary : SBColor.textSecondary)
        .padding(.vertical, scale(4))
        .padding(.horizontal, scale(9))
        .background(isEditable ? SBColor.surface : .clear)
        .overlay(
            RoundedRectangle(cornerRadius: SBRadius.control, style: .continuous)
                .strokeBorder(isEditable ? SBColor.borderStrong : SBColor.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: SBRadius.control, style: .continuous))
    }
}

extension Chip where Leading == EmptyView {
    public init(_ text: String, isEditable: Bool = false) {
        self.init(text, isEditable: isEditable) { EmptyView() }
    }
}

/// A tag: full pill radius, 1px border, 11pt.
public struct Tag: View {
    private let text: String
    @Environment(\.sbScale) private var scale

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .sbFont(11)
            .foregroundStyle(SBColor.textSecondary)
            .padding(.vertical, scale(2))
            .padding(.horizontal, scale(8))
            .background(SBColor.canvas)
            .overlay(Capsule().strokeBorder(SBColor.border, lineWidth: 1))
            .clipShape(Capsule())
    }
}
