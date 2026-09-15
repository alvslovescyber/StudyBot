import Fluent
import Vapor

/// `studybotctl pair`: prints a six-word code valid for ten minutes, single use (§3.6).
struct PairCommand: AsyncCommand {
    struct Signature: CommandSignature {}

    var help: String { "Print a one-time pairing code for a Mac to enter in Settings → Sync." }

    func run(using context: CommandContext, signature: Signature) async throws {
        let app = context.application
        let code = try await Pairing.issueCode(on: app.db, secret: app.settings.pairingSecret, now: Date())
        context.console.output("Pairing code (valid 10 minutes, single use):", style: .info)
        context.console.output("")
        context.console.output("    \(code)", style: .success)
        context.console.output("")
        context.console.output(
            "On the Mac: Settings → Sync → Pair this Mac, then type the six words.", style: .plain)
    }
}
