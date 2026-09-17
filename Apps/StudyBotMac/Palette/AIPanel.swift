import AppKit
import StudyBotKit
import StudyBotUI
import SwiftUI

/// The answer to ⌘K "Explain" (§6.7, §9 `AIPanel`): the question, the text, Copy, and the
/// one line of cost. Streaming arrives with SSE; for now the panel waits, briefly.
struct AIPanel: View {
    @Environment(AppModel.self) private var model
    @Environment(\.sbScale) private var scale
    let explanation: AppModel.Explanation

    private var current: AppModel.Explanation { model.explanation ?? explanation }

    var body: some View {
        VStack(alignment: .leading, spacing: scale(14)) {
            HStack(spacing: scale(8)) {
                Image(systemName: "sparkles").sbFont(13, weight: .medium).foregroundStyle(SBColor.accent)
                Text(current.question).sbType(SBType.section).fontWeight(.semibold).foregroundStyle(
                    SBColor.textPrimary)
                Spacer()
                Btn.secondary("Done", size: .small) { model.explanation = nil }
            }
            if let answer = current.answer {
                ScrollView {
                    Text(answer)
                        .sbFont(14)
                        .lineSpacing(scale(4))
                        .foregroundStyle(SBColor.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                HStack(spacing: scale(8)) {
                    Btn.secondary("Copy", size: .small) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(answer, forType: .string)
                    }
                    if let run = model.ai?.runs.first {
                        Text("\(run.inputTokens + run.outputTokens) tokens · recorded in the AI-use record")
                            .sbFont(11.5).foregroundStyle(SBColor.textTertiary)
                    }
                    Spacer()
                }
            } else if let error = current.error {
                Text(error).sbFont(13).foregroundStyle(SBColor.danger)
                if model.ai?.canRetry == true {
                    Btn.secondary("Try again", size: .small) {
                        Task { await model.explain(current.question) }
                    }
                }
            } else {
                HStack(spacing: scale(8)) {
                    ProgressView().controlSize(.small)
                    Text("Asking…").sbFont(13).foregroundStyle(SBColor.textSecondary)
                }
            }
        }
        .padding(SBSpacing.region)
        .frame(width: 560, height: 360)
        .background(SBColor.surface)
    }
}
