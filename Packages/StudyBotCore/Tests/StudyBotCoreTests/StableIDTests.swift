import Foundation
import StudyBotCore
import Testing

@Suite("StableID")
struct StableIDTests {
    @Test("the same input always yields the same UUID")
    func deterministic() {
        let a = StableID.uuid(namespace: "ns", name: "COM1018DA")
        let b = StableID.uuid(namespace: "ns", name: "COM1018DA")
        #expect(a == b)
    }

    @Test("a different name or namespace yields a different UUID")
    func distinct() {
        let a = StableID.uuid(namespace: "ns", name: "COM1018DA")
        let b = StableID.uuid(namespace: "ns", name: "COM1014DA")
        let c = StableID.uuid(namespace: "other", name: "COM1018DA")
        #expect(a != b)
        #expect(a != c)
        #expect(b != c)
    }

    @Test("the result is a well-formed RFC 9562 version-8 UUID")
    func wellFormed() {
        let id = StableID.uuid(namespace: "ns", name: "anything")
        let text = id.uuidString
        // xxxxxxxx-xxxx-8xxx-Vxxx-xxxxxxxxxxxx where V is 8, 9, A or B.
        #expect(text.count == 36)
        let version = text[text.index(text.startIndex, offsetBy: 14)]
        let variant = text[text.index(text.startIndex, offsetBy: 19)]
        #expect(version == "8")
        #expect(["8", "9", "A", "B"].contains(variant))
    }

    @Test("thousands of distinct UID-shaped strings yield distinct UUIDs")
    func noCollisionsAcrossRealUIDs() {
        var seen = Set<UUID>()
        var count = 0
        for kind in ["online-lectures", "online-workshops", "assignment", "bank-holiday", "on-campus"] {
            for day in 0..<2000 {
                let uid = "dtsl6-2026-\(kind)-day\(day)@programme.calendar"
                seen.insert(StableID.uuid(namespace: StableID.Namespace.programmeEvent, name: uid))
                count += 1
            }
        }
        #expect(seen.count == count)
    }

    @Test("the pinned value does not change between builds")
    func pinned() {
        // If this fails, every derived id in every installed database changes. Do not update
        // the expectation without a migration.
        let id = StableID.uuid(namespace: StableID.Namespace.module, name: "COM1018DA")
        #expect(id == Module.stableID(forCode: "com1018da"))
        #expect(id.uuidString == Self.pinnedCOM1018DA)
    }

    /// Captured when StableID was first written (14 Sep 2026). A permanent constant.
    static let pinnedCOM1018DA = "CC8517AF-6CC9-8D1E-A6B9-F9B3E4BF29B2"
}
