import Fluent
import Foundation
import Vapor

/// `studybotctl purge-tombstones`: removes deletions older than 90 days (§3.4). Safe to run
/// any time; `sync_log` keeps every seq so cursors stay valid.
struct PurgeTombstonesCommand: AsyncCommand {
    struct Signature: CommandSignature {}

    var help: String { "Remove tombstones older than 90 days." }

    func run(using context: CommandContext, signature: Signature) async throws {
        let removed = try await SyncService(db: context.application.db, now: Date()).purgeTombstones()
        context.console.output("Removed \(removed) tombstone(s).", style: .success)
    }
}
