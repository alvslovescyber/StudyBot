import Foundation

/// Response to a successful pairing (spec §3.6): the long-lived bearer token, shown once and
/// then kept only in the Keychain, plus the server's record of this device so it can be
/// named and revoked individually.
public struct PairResponse: Codable, Hashable, Sendable {
    public var token: String
    /// The server's id for this device's token row.
    public var deviceRecordID: UUID
    public var deviceName: String

    public init(token: String, deviceRecordID: UUID, deviceName: String) {
        self.token = token
        self.deviceRecordID = deviceRecordID
        self.deviceName = deviceName
    }
}
