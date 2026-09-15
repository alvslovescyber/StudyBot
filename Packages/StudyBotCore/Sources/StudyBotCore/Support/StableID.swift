import Foundation

/// Deterministic UUIDs for records that every device derives independently from the same
/// input: programme events (from the ICS UID), modules (from the module code) and terms.
///
/// Why: both Macs import the bundled calendar on their own (§4). If each minted a random
/// UUID for "COM1018DA", the two would disagree about which record is which. Deriving the
/// id from the input makes the import converge without the server having to arbitrate.
///
/// The hash is FNV-1a folded to 128 bits, with the RFC 4122 version and variant bits set
/// so the result is a well-formed UUID. It is not cryptographic and does not need to be:
/// the inputs are a few hundred short, distinct strings.
public enum StableID {
    /// A UUID derived from `namespace` and `name`. Same inputs, same UUID, forever.
    public static func uuid(namespace: String, name: String) -> UUID {
        let input = Array("\(namespace)\u{1F}\(name)".utf8)
        let high = fnv1a64(input, basis: 0xcbf2_9ce4_8422_2325)
        let low = fnv1a64(input, basis: 0x84222325_cbf29ce4 ^ 0x9E37_79B9_7F4A_7C15)

        var bytes = [UInt8](repeating: 0, count: 16)
        for index in 0..<8 {
            bytes[index] = UInt8(truncatingIfNeeded: high >> (8 * (7 - index)))
            bytes[8 + index] = UInt8(truncatingIfNeeded: low >> (8 * (7 - index)))
        }
        // Version 8 ("custom") and RFC 4122 variant, per RFC 9562.
        bytes[6] = (bytes[6] & 0x0F) | 0x80
        bytes[8] = (bytes[8] & 0x3F) | 0x80

        return UUID(
            uuid: (
                bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
            ))
    }

    private static func fnv1a64(_ bytes: [UInt8], basis: UInt64) -> UInt64 {
        var hash = basis
        for byte in bytes {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return hash
    }
}

extension StableID {
    /// Namespaces used across the app. Changing one changes every derived id, so treat
    /// these as permanent.
    public enum Namespace {
        public static let programmeEvent = "studybot.programmeEvent"
        public static let module = "studybot.module"
        public static let term = "studybot.term"
        public static let settings = "studybot.settings"
        public static let assignmentStub = "studybot.assignmentStub"
        public static let session = "studybot.session"
    }
}
