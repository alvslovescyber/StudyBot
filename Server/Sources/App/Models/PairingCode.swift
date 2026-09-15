import Fluent
import Foundation
import Vapor

/// `pairing_codes`: a six-word code `studybotctl pair` printed, stored as an HMAC so the row
/// is useless without the pairing secret. Valid ten minutes, single use (§3.6).
final class PairingCode: Model, @unchecked Sendable {
    static let schema = "pairing_codes"

    /// How long a code is valid.
    static let validity: TimeInterval = 10 * 60

    @ID(key: .id) var id: UUID?
    @Field(key: "code_hash") var codeHash: String
    @Field(key: "created_at") var createdAt: Double
    @Field(key: "expires_at") var expiresAt: Double
    @OptionalField(key: "used_at") var usedAt: Double?

    init() {}

    init(codeHash: String, createdAt: Date) {
        self.codeHash = codeHash
        self.createdAt = createdAt.timeIntervalSince1970
        expiresAt = createdAt.addingTimeInterval(PairingCode.validity).timeIntervalSince1970
    }

    func isUsable(at now: Date) -> Bool {
        usedAt == nil && now.timeIntervalSince1970 < expiresAt
    }
}
