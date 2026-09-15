import AppKit
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
                Task { await sync.pair(serverAddress: serverAddress, code: code, deviceName: deviceName) }
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
                    Task { await sync.unpair() }
                }
            }
            Text("Unpairing forgets the server and the token on this Mac only. Nothing is deleted anywhere.")
                .sbFont(11.5)
                .foregroundStyle(SBColor.textTertiary)
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
