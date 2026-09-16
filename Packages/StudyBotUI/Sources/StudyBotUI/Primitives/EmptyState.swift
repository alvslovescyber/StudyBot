import SwiftUI

/// An empty state (spec §9 "Empty states and errors"): one line saying what goes here and
/// one action that puts something there. No illustration, no "Nothing here yet!".
public struct EmptyState: View {
    private let message: String
    private let actionTitle: String?
    private let action: (() -> Void)?

    public init(_ message: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        VStack(spacing: SBSpacing.x3) {
            Text(message)
                .sbType(SBType.body)
                .foregroundStyle(SBColor.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            if let actionTitle, let action {
                Btn.secondary(actionTitle, size: .small, action: action)
            }
        }
        .padding(SBSpacing.region)
        .frame(maxWidth: .infinity)
    }
}
