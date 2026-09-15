import Foundation
import StudyBotKit
import Testing

/// Touches the real Keychain, so it runs only when asked: `STUDYBOT_KEYCHAIN_TESTS=1 swift test`.
/// CI runners have a locked keychain and skip it.
@Suite("KeychainCredentialStore — real Keychain, opt in")
struct KeychainCredentialStoreTests {
    @Test(
        "save, read back, clear",
        .enabled(if: ProcessInfo.processInfo.environment["STUDYBOT_KEYCHAIN_TESTS"] == "1"))
    func roundTrip() throws {
        let store = KeychainCredentialStore(
            service: "com.alvisbabu.studybot.tests", account: UUID().uuidString)
        #expect(try store.token() == nil)
        try store.save(token: "first")
        #expect(try store.token() == "first")
        try store.save(token: "second")
        #expect(try store.token() == "second", "save replaces")
        try store.clear()
        #expect(try store.token() == nil)
        try store.clear()
    }
}
