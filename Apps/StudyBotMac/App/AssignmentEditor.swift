import Foundation
import Observation
import StudyBotCore
import StudyBotKit

/// Edit mode for the assignment detail panel (§6.2 "Editing is a mode, not a free-for-all").
/// Read-only by default. `begin` takes a copy; the panel edits the copy; `save` writes once
/// through the store; `requestCancel` asks before discarding anything that changed.
@MainActor
@Observable
final class AssignmentEditor {
    private(set) var original: Assignment?
    /// The copy being edited. Non-nil means edit mode.
    var draft: Assignment?
    /// The "Discard changes to this assignment?" confirmation is showing.
    var isConfirmingDiscard = false

    var isEditing: Bool { draft != nil }

    var hasChanges: Bool {
        guard let draft, let original else { return false }
        return !changedFields(from: original, to: draft).isEmpty
    }

    func begin(_ assignment: Assignment) {
        original = assignment
        draft = assignment
    }

    /// Cancel: confirms first if anything changed, otherwise leaves edit mode at once.
    func requestCancel() {
        if hasChanges {
            isConfirmingDiscard = true
        } else {
            discard()
        }
    }

    /// Leaves edit mode, dropping the draft.
    func discard() {
        draft = nil
        original = nil
        isConfirmingDiscard = false
    }

    /// Writes the draft exactly once and leaves edit mode. Stays in edit mode if the store
    /// refused it (a blank title, say) so the user can fix it.
    func save(using store: AssignmentStore) async {
        guard let draft, let original else { return }
        let changed = changedFields(from: original, to: draft)
        guard !changed.isEmpty else {
            discard()
            return
        }
        await store.save(draft, changedFields: changed)
        if store.lastError == nil {
            discard()
        }
    }

    /// The editable fields (§6.2 "Scope of what's editable") that differ between two versions.
    /// These names are what ELE2 field ownership keys on, so they match the model's property names.
    func changedFields(from original: Assignment, to draft: Assignment) -> Set<String> {
        var changed = Set<String>()
        if original.title != draft.title { changed.insert("title") }
        if original.moduleID != draft.moduleID { changed.insert("moduleID") }
        if original.status != draft.status { changed.insert("status") }
        if original.priority != draft.priority { changed.insert("priority") }
        if original.dueDate.map(LocalDay.init) != draft.dueDate.map(LocalDay.init) {
            changed.insert("dueDate")
        }
        if original.wordLimit != draft.wordLimit { changed.insert("wordLimit") }
        if original.weighting != draft.weighting { changed.insert("weighting") }
        if original.briefText != draft.briefText { changed.insert("briefText") }
        if original.rubricText != draft.rubricText { changed.insert("rubricText") }
        if original.grade != draft.grade { changed.insert("grade") }
        if original.feedback != draft.feedback { changed.insert("feedback") }
        if original.targetGrade != draft.targetGrade { changed.insert("targetGrade") }
        return changed
    }
}
