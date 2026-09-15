import SwiftUI

/// Menu items and their shortcuts (§10). Every shortcut appears in a menu; nothing is hidden.
/// The sidebar shows no keyboard hints, so this is where ⌘1–⌘5 and ⌥⌘S are discoverable.
struct AppCommands: Commands {
    let model: AppModel

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New assignment") {
                Task { await model.createAssignment() }
            }
            .keyboardShortcut("n", modifiers: .command)
        }

        CommandMenu("View") {
            ForEach(SidebarItem.allCases) { item in
                Button(item.title) { model.selection = item }
                    .keyboardShortcut(item.shortcutKey, modifiers: .command)
            }
            Divider()
            Button(model.sidebarCollapsed ? "Show sidebar" : "Hide sidebar") {
                withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) {
                    model.sidebarCollapsed.toggle()
                }
            }
            .keyboardShortcut("s", modifiers: [.command, .option])
        }

        CommandMenu("Assignment") {
            Button("Edit") { model.beginEditingSelected() }
                .keyboardShortcut("e", modifiers: .command)
                .disabled(model.selectedAssignment == nil || model.editor.isEditing)
            Button("Save changes") { Task { await model.saveEditing() } }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(!model.editor.isEditing)
            Button(model.editor.isEditing ? "Cancel editing" : "Close panel") { model.escape() }
                .keyboardShortcut(.escape, modifiers: [])
                .disabled(model.selectedAssignment == nil)
        }
    }
}
