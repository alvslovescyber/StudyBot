import Foundation
import Security
import StudyBotCore

/// The bearer token in the Keychain (spec §3.6), as a generic password item in the data
/// protection keychain with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`: readable
/// after the first unlock, never synced to another device, never in `UserDefaults`.
public struct KeychainCredentialStore: SyncCredentialStore {
    public enum Error: Swift.Error, Equatable {
        case status(OSStatus)
    }

    private let service: String
    private let account: String

    public init(service: String = "com.alvisbabu.studybot.sync", account: String = "server-token") {
        self.service = service
        self.account = account
    }

    private var baseQuery: [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecUseDataProtectionKeychain: true,
        ]
    }

    public func token() throws -> String? {
        var query = baseQuery
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data else { return nil }
            return String(data: data, encoding: .utf8)
        case errSecItemNotFound:
            return nil
        default:
            throw Error.status(status)
        }
    }

    public func save(token: String) throws {
        try clear()
        var attributes = baseQuery
        attributes[kSecValueData] = Data(token.utf8)
        attributes[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else { throw Error.status(status) }
    }

    public func clear() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw Error.status(status) }
    }
}
