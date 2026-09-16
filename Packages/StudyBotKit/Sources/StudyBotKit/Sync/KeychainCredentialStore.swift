import Foundation
import Security
import StudyBotCore

/// The bearer token in the Keychain (spec §3.6), as a generic password item in the data
/// protection keychain with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`: readable
/// after the first unlock, never synced to another device, never in `UserDefaults`.
///
/// The data protection keychain needs an application identifier, which a locally-signed
/// build (§3.10a, no Developer Program yet) does not have. When the system says so
/// (`errSecMissingEntitlement`), the store falls back to the login keychain, which is still
/// the Keychain and still not `UserDefaults`; the accessibility attribute is the one thing
/// lost until the app is signed with a team. See docs/decisions.md.
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

    /// The account a build uses: `server-token`, or one per store when a Debug build runs on
    /// an alternate store, so two instances on one Mac keep separate tokens.
    public static var defaultAccount: String {
        #if DEBUG
            if let path = ProcessInfo.processInfo.environment["STUDYBOT_STORE_PATH"], !path.isEmpty {
                let file = path.split(separator: "/").last.map(String.init) ?? path
                return "server-token-" + file.replacingOccurrences(of: ".", with: "-")
            }
        #endif
        return "server-token"
    }

    private func baseQuery(dataProtection: Bool) -> [CFString: Any] {
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]
        if dataProtection {
            query[kSecUseDataProtectionKeychain] = true
        }
        return query
    }

    public func token() throws -> String? {
        // Look in both keychains: a token saved through the fallback is not in the first.
        for dataProtection in [true, false] {
            var query = baseQuery(dataProtection: dataProtection)
            query[kSecReturnData] = true
            query[kSecMatchLimit] = kSecMatchLimitOne
            var item: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &item)
            switch status {
            case errSecSuccess:
                guard let data = item as? Data else { continue }
                return String(data: data, encoding: .utf8)
            case errSecItemNotFound, errSecMissingEntitlement, errSecNotAvailable:
                continue
            default:
                throw Error.status(status)
            }
        }
        return nil
    }

    public func save(token: String) throws {
        try clear()
        _ = try withKeychain { dataProtection in
            var attributes = baseQuery(dataProtection: dataProtection)
            attributes[kSecValueData] = Data(token.utf8)
            if dataProtection {
                attributes[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            }
            return ((), SecItemAdd(attributes as CFDictionary, nil))
        }
    }

    public func clear() throws {
        _ = try withKeychain { dataProtection in
            let status = SecItemDelete(baseQuery(dataProtection: dataProtection) as CFDictionary)
            return ((), status == errSecItemNotFound ? errSecSuccess : status)
        }
    }

    /// Runs `operation` against the data protection keychain, and again against the login
    /// keychain if the first is unavailable to an unsigned build.
    private func withKeychain<T>(_ operation: (Bool) -> (T, OSStatus)) throws -> T {
        let (value, status) = operation(true)
        if status == errSecSuccess { return value }
        if status == errSecMissingEntitlement || status == errSecNotAvailable {
            let (fallback, fallbackStatus) = operation(false)
            guard fallbackStatus == errSecSuccess else { throw Error.status(fallbackStatus) }
            return fallback
        }
        throw Error.status(status)
    }
}
