import Foundation
import StudyBotCore
import StudyBotKit
import Testing

/// §3.12 row "Confidentiality guard": content flagged confidential never appears in an
/// assembled prompt, through any code path. A failure here is a build-breaking bug (§7.4).
@Suite("PromptAssembler — §7.3a templates and the §7.4 guard")
struct PromptAssemblerTests {
    private let secret = "PAYROLL-MIGRATION-INCIDENT-2026"

    @Test("confidential content never reaches a prompt, for every capability this build offers")
    func confidentialNeverAssembled() {
        for capability in PromptAssembler.supported {
            let inputs = PromptAssembler.Inputs(
                moduleCode: "COM1018DA", moduleName: "Programming",
                items: [
                    AIContextItem(label: "Live notes", text: "public notes"),
                    AIContextItem(label: "Evidence", text: secret, isWorkConfidential: true),
                ])
            #expect(throws: ConfidentialContentError(labels: ["Evidence"])) {
                try PromptAssembler.request(for: capability, inputs: inputs)
            }
        }
        // Even a confidential item with empty text is refused: the flag decides, not the length.
        #expect(throws: ConfidentialContentError.self) {
            try PromptAssembler.request(
                for: .explain,
                inputs: PromptAssembler.Inputs(items: [
                    AIContextItem(label: "x", text: "", isWorkConfidential: true)
                ]))
        }
    }

    @Test("a clean request carries the context block, the template and the items, and is not flagged")
    func assembles() throws {
        let request = try PromptAssembler.request(
            for: .structureNotes,
            inputs: PromptAssembler.Inputs(
                moduleCode: "COM1014DA", moduleName: "Discrete Mathematics for Computer Science",
                items: [
                    AIContextItem(label: "Live notes", text: "- sets\nASK: does order matter"),
                    AIContextItem(label: "Transcript", text: ""),
                ]))
        #expect(request.capability == .structureNotes)
        #expect(!request.containsConfidential)
        #expect(request.promptVersion == PromptTemplates.version)
        #expect(request.messages.count == 2)
        let system = request.messages[0].content
        #expect(system.contains("Module: COM1014DA Discrete Mathematics for Computer Science"))
        #expect(system.contains("British English"))
        let user = request.messages[1].content
        #expect(user.contains("Summary (exactly 3 bullets)"))
        #expect(user.contains("### Live notes\n- sets\nASK: does order matter"))
        #expect(!user.contains("### Transcript"), "empty items are left out")
        #expect(!secret.isEmpty && !user.contains(secret))
    }

    @Test("capabilities without a template yet are refused, not improvised")
    func unsupported() {
        #expect(throws: UnsupportedCapability(capability: .checkDraft)) {
            try PromptAssembler.request(for: .checkDraft, inputs: PromptAssembler.Inputs(items: []))
        }
    }

    @Test("the budget arithmetic warns at 80% and stops at 100%, in pence")
    func budget() {
        let fine = AIBudget(spentPence: 600, capPence: 800)
        #expect(!fine.isWarning && !fine.isExhausted && fine.remainingPence == 200)
        #expect(AIBudget(spentPence: 640, capPence: 800).isWarning)
        #expect(AIBudget(spentPence: 800, capPence: 800).isExhausted)
        #expect(AIBudget.pounds(800) == "£8" && AIBudget.pounds(1_250) == "£12.50")
    }
}
