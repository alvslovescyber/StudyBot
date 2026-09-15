import StudyBotCore
import Vapor

/// `POST /v1/auth/pair` (§3.6): a one-time code for a long-lived token.
struct AuthRoutes: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        routes.post("auth", "pair") { req async throws -> Response in
            let body = try req.content.decode(PairRequest.self, using: SyncContentDecoder())
            let response = try await Pairing.redeem(
                body, on: req.db, secret: req.application.settings.pairingSecret, now: Date())
            req.logger.info("paired a device")
            return try SyncContentEncoder.response(response, status: .ok)
        }
    }
}
