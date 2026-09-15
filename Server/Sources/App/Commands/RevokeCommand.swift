import Fluent
import Foundation
import Vapor

/// `studybotctl revoke <device-id>`: a lost laptop costs one revocation (§3.6).
struct RevokeCommand: AsyncCommand {
    struct Signature: CommandSignature {
        @Argument(name: "device-id", help: "The id shown by studybotctl devices")
        var deviceID: String
    }

    var help: String {
        "Revoke one device's token. The Mac keeps working offline and must pair again to sync."
    }

    func run(using context: CommandContext, signature: Signature) async throws {
        guard let id = UUID(uuidString: signature.deviceID),
            let device = try await DeviceToken.find(id, on: context.application.db)
        else {
            context.console.output("No device with that id. Run studybotctl devices.", style: .error)
            return
        }
        device.revokedAt = Date().timeIntervalSince1970
        try await device.save(on: context.application.db)
        context.console.output("Revoked \(device.name).", style: .success)
    }
}
