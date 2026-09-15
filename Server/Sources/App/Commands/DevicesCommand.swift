import Fluent
import Foundation
import Vapor

/// `studybotctl devices`: every paired Mac, with when it was last seen (§3.6).
struct DevicesCommand: AsyncCommand {
    struct Signature: CommandSignature {}

    var help: String { "List paired devices with their ids, so one can be revoked." }

    func run(using context: CommandContext, signature: Signature) async throws {
        let devices = try await DeviceToken.query(on: context.application.db).sort(\.$createdAt).all()
        if devices.isEmpty {
            context.console.output("No devices paired yet. Run studybotctl pair.", style: .info)
            return
        }
        let formatter = ISO8601DateFormatter()
        for device in devices {
            let seen =
                device.lastSeenAt.map { formatter.string(from: Date(timeIntervalSince1970: $0)) } ?? "never"
            let state = device.isRevoked ? "revoked" : "active"
            context.console.output(
                "\(device.id?.uuidString ?? "?")  \(device.name)  \(state)  last seen \(seen)", style: .plain)
        }
    }
}
