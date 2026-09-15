import Crypto
import Fluent
import Foundation
import StudyBotCore
import Vapor

// Fluent's `.filter(...).first()` is a query, not a collection; SwiftLint reads it as one.
// swiftlint:disable first_where

/// Pairing codes and device tokens (§3.6). A code is six words from a 256-word list, spoken
/// or typed across the room; a token is 32 random bytes the Mac keeps in its Keychain. The
/// server stores only hashes of either.
enum Pairing {
    /// Issues a new code, valid ten minutes, and stores its HMAC.
    static func issueCode(on db: any Database, secret: String, now: Date) async throws -> String {
        let words = (0..<6).map { _ in PairingWords.list[Int.random(in: 0..<PairingWords.list.count)] }
        let code = words.joined(separator: " ")
        try await PairingCode(codeHash: hash(code: code, secret: secret), createdAt: now).save(on: db)
        return code
    }

    /// Exchanges a code for a token. The code is marked used in the same transaction that
    /// creates the token, so it cannot be redeemed twice.
    static func redeem(_ request: PairRequest, on db: any Database, secret: String, now: Date) async throws
        -> PairResponse
    {
        let name = request.deviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 60 else {
            throw Abort(.badRequest, reason: "Give this Mac a name of up to 60 characters.")
        }
        let codeHash = hash(code: request.code, secret: secret)
        return try await db.transaction { db in
            guard let code = try await PairingCode.query(on: db).filter(\.$codeHash == codeHash).first(),
                code.isUsable(at: now)
            else {
                throw Abort(
                    .unauthorized,
                    reason: "That pairing code is not valid. Run studybotctl pair for a new one.")
            }
            code.usedAt = now.timeIntervalSince1970
            try await code.save(on: db)
            let token = randomToken()
            let device = DeviceToken(name: name, tokenHash: hash(token: token), createdAt: now)
            try await device.save(on: db)
            guard let id = device.id else { throw Abort(.internalServerError) }
            return PairResponse(token: token, deviceRecordID: id, deviceName: name)
        }
    }

    /// Codes are compared case- and whitespace-insensitively, then HMAC-SHA256 with the secret.
    static func hash(code: String, secret: String) -> String {
        let normalised = code.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
        let key = SymmetricKey(data: Data(secret.utf8))
        let mac = HMAC<SHA256>.authenticationCode(for: Data(normalised.utf8), using: key)
        return Data(mac).map { String(format: "%02x", $0) }.joined()
    }

    static func hash(token: String) -> String {
        SHA256.hash(data: Data(token.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// 32 random bytes, base64url without padding.
    static func randomToken() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        for index in bytes.indices {
            bytes[index] = UInt8.random(in: .min ... .max)
        }
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

/// Bearer authentication against `device_tokens`. A revoked or unknown token is a 401 the
/// client turns into "pair again"; a valid one updates `last_seen_at` for Settings.
struct DeviceTokenAuthenticator: AsyncBearerAuthenticator {
    func authenticate(bearer: BearerAuthorization, for request: Request) async throws {
        let tokenHash = Pairing.hash(token: bearer.token)
        let match = try await DeviceToken.query(on: request.db).filter(\.$tokenHash == tokenHash).first()
        guard let device = match, !device.isRevoked else { return }
        device.lastSeenAt = Date().timeIntervalSince1970
        try? await device.save(on: request.db)
        request.auth.login(device)
    }
}
// swiftlint:enable first_where
