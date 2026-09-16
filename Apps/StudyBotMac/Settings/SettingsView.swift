import AppKit
import StudyBotCore
import StudyBotKit
import StudyBotUI
import SwiftUI

/// Settings (§6.8). Seven sections eventually; Sync is the one that exists, because it is the
/// one milestone four built. The unpaired state carries §6.0's single honest row rather than a
/// modal: the app works without a server, and says so.
struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Settings")
                    .sbType(SBType.title)
                    .foregroundStyle(SBColor.textPrimary)
                if let sync = model.sync {
                    SyncSection(sync: sync)
                        .padding(.top, 24)
                    AISection()
                        .padding(.top, 28)
                    DataSection()
                        .padding(.top, 28)
                } else {
                    Text("Sync becomes available once the store has opened.")
                        .sbType(SBType.body)
                        .foregroundStyle(SBColor.textSecondary)
                        .padding(.top, 24)
                }
            }
            .padding(SBSpacing.detailOuter)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(SBColor.surface)
        .frame(minWidth: 520, minHeight: 420)
    }
}

/// §6.8 "Sync": pair a Mac, see where things stand, sync now, unpair.
private struct SyncSection: View {
    @Environment(AppModel.self) private var model
    @Bindable var sync: SyncStore
    @State private var serverAddress = ""
    @State private var code = ""
    @State private var deviceName = Host.current().localizedName ?? "This Mac"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sync")
                .sbFont(12, weight: .semibold)
                .foregroundStyle(SBColor.textSecondary)
            if sync.isPaired {
                paired
            } else {
                unpaired
            }
        }
    }

    private var unpaired: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connect StudyBot to your server to sync with your other Mac.")
                .sbType(SBType.body)
                .foregroundStyle(SBColor.textPrimary)
            Text("On the server, run studybotctl pair and type the six words here. Nothing else is needed.")
                .sbFont(12)
                .foregroundStyle(SBColor.textSecondary)

            LabelledField("Server address") {
                TextField("studybot.example.com", text: $serverAddress).sbInput()
            }
            LabelledField("This Mac's name") {
                TextField("MacBook Air", text: $deviceName).sbInput()
            }
            LabelledField("Pairing code") {
                TextField("six words", text: $code).sbInput()
            }
            if let error = sync.pairingError {
                Text(error)
                    .sbFont(12)
                    .foregroundStyle(SBColor.danger)
            }
            Btn.primary(sync.isPairing ? "Pairing…" : "Pair this Mac", icon: "link") {
                Task {
                    await sync.pair(serverAddress: serverAddress, code: code, deviceName: deviceName)
                    await model.refreshAI()
                }
            }
            .disabled(sync.isPairing || serverAddress.isEmpty || code.isEmpty || deviceName.isEmpty)
        }
    }

    private var paired: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(
                "Paired as \(sync.state.deviceName ?? "this Mac") with \(sync.state.serverURL?.host() ?? "the server")."
            )
            .sbType(SBType.body)
            .foregroundStyle(SBColor.textPrimary)
            Text(sync.statusLine)
                .sbFont(12)
                .foregroundStyle(sync.state.lastError == nil ? SBColor.textSecondary : SBColor.danger)
            HStack(spacing: 8) {
                Btn.secondary(sync.isSyncing ? "Syncing…" : "Sync now", size: .small) {
                    Task { await sync.syncNow() }
                }
                .disabled(sync.isSyncing)
                Btn.secondary("Unpair this Mac", size: .small) {
                    Task {
                        await sync.unpair()
                        await model.refreshAI()
                    }
                }
            }
            Text("Unpairing forgets the server and the token on this Mac only. Nothing is deleted anywhere.")
                .sbFont(11.5)
                .foregroundStyle(SBColor.textTertiary)
        }
    }
}

/// §6.8 "AI": spend this month against the cap and the AI-use record (§7.5). The cap itself
/// is the server's `AI_MONTHLY_CAP_PENCE`; raising it is an edit to the server's env file.
private struct AISection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.sbScale) private var scale

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AI").sbFont(12, weight: .semibold).foregroundStyle(SBColor.textSecondary)
            if let ai = model.ai, ai.isAvailable {
                if let budget = ai.budget {
                    HStack(spacing: scale(10)) {
                        ProgressBar(
                            budget.capPence > 0 ? Double(budget.spentPence) / Double(budget.capPence) : 0,
                            width: scale(160),
                            colour: budget.isWarning ? SBColor.statusDrafting : SBColor.accent)
                        Text(
                            "\(AIBudget.pounds(budget.spentPence)) of \(AIBudget.pounds(budget.capPence)) this month"
                        )
                        .sbFont(12).foregroundStyle(SBColor.textPrimary)
                        Btn.secondary("Refresh", size: .small) { Task { await ai.refreshBudget() } }
                    }
                    Text(
                        "The cap is set on the server (AI_MONTHLY_CAP_PENCE). At the cap the server refuses and says so."
                    )
                    .sbFont(11.5).foregroundStyle(SBColor.textTertiary)
                } else {
                    Text("Budget not fetched yet.").sbFont(12).foregroundStyle(SBColor.textSecondary)
                }
                Text("AI-use record").sbFont(12, weight: .semibold).foregroundStyle(SBColor.textSecondary)
                    .padding(.top, 6)
                if ai.runs.isEmpty {
                    Text(
                        "No AI runs yet. Every run is listed here: what was asked, when, and how many tokens."
                    )
                    .sbFont(12).foregroundStyle(SBColor.textTertiary)
                } else {
                    ForEach(ai.runs.prefix(20)) { run in
                        HStack(spacing: scale(8)) {
                            Text(
                                RelativeDate.absolute(run.timestamp, relativeTo: model.now()) + " "
                                    + RelativeDate.time(run.timestamp)
                            )
                            .sbFont(11.5).foregroundStyle(SBColor.textTertiary).monospacedDigit()
                            .frame(width: scale(96), alignment: .leading)
                            Text(run.capability.rawValue).sbFont(11.5, weight: .medium).foregroundStyle(
                                SBColor.accent)
                            Text(run.promptSummary).sbFont(12).foregroundStyle(SBColor.textPrimary).lineLimit(
                                1)
                            Spacer()
                            Text("\(run.inputTokens + run.outputTokens) tokens").sbFont(11.5).foregroundStyle(
                                SBColor.textTertiary)
                        }
                    }
                }
            } else {
                Text(
                    "AI runs through your server (§3.7): the key stays there, the cap is enforced there. Pair this Mac to use it; notes work without it."
                )
                .sbFont(12).foregroundStyle(SBColor.textSecondary)
            }
        }
    }
}

/// §6.8 "Data": export everything, restore from an export. The export is the third copy the
/// two Macs do not give you (§16); run it after every block.
private struct DataSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.sbScale) private var scale
    @State private var isWorking = false
    @State private var confirmingRestore: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data")
                .sbFont(12, weight: .semibold)
                .foregroundStyle(SBColor.textSecondary)
            Text(
                "An export is a folder in Downloads: your notes as Markdown, every record as JSON, the calendar, and every kept version. Readable without StudyBot. Run it after each block."
            )
            .sbFont(12)
            .foregroundStyle(SBColor.textSecondary)
            HStack(spacing: scale(8)) {
                Btn.primary(
                    isWorking ? "Exporting…" : "Export everything", icon: "square.and.arrow.up", size: .small
                ) {
                    Task {
                        isWorking = true
                        await model.exportEverything()
                        isWorking = false
                    }
                }
                .disabled(isWorking)
                Btn.secondary("Restore from an export…", size: .small) { chooseExport() }
                    .disabled(isWorking)
                if let url = model.lastExportURL {
                    Btn.secondary("Show in Finder", size: .small) {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                }
            }
            Text(
                model.lastAutomaticExportAt.map {
                    "Weekly export: last ran \(RelativeDate.absolute($0, relativeTo: model.now())). Twelve are kept."
                } ?? "Weekly export: runs on the next launch, then every seven days. Twelve are kept."
            )
            .sbFont(12)
            .foregroundStyle(SBColor.textSecondary)
            if let automatic = model.automaticExportStatus, automatic.contains("could not") {
                Text(automatic).sbFont(12).foregroundStyle(SBColor.danger)
            }
            if let status = model.dataStatus {
                Text(status)
                    .sbFont(12)
                    .foregroundStyle(
                        status.contains("could not") || status.contains("Couldn't")
                            || status.contains("not a StudyBot") ? SBColor.danger : SBColor.textSecondary)
            }
        }
        .confirmationDialog(
            "Restore this export?",
            isPresented: Binding(
                get: { confirmingRestore != nil }, set: { if !$0 { confirmingRestore = nil } }),
            titleVisibility: .visible
        ) {
            Button("Restore") {
                guard let folder = confirmingRestore else { return }
                Task {
                    isWorking = true
                    await model.restore(from: folder)
                    isWorking = false
                }
            }
            Button("Cancel", role: .cancel) { confirmingRestore = nil }
        } message: {
            Text(
                "Records in the export replace records with the same id on this Mac. Nothing else is touched, and the next sync reconciles with the server."
            )
        }
    }

    private func chooseExport() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Restore"
        panel.message = "Choose a StudyBot export folder."
        if panel.runModal() == .OK, let url = panel.url {
            confirmingRestore = url
        }
    }
}

private struct LabelledField<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    init(_ label: String, @ViewBuilder content: @escaping () -> Content) {
        self.label = label
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).sbFont(12).foregroundStyle(SBColor.textSecondary)
            content()
        }
    }
}
