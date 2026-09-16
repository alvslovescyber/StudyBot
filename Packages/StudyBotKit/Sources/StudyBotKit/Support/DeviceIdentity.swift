import Foundation

/// A stable identifier for this Mac, written into `SyncMetadata.deviceID` on every local edit
/// so the last-write-wins tie-break (§4) has something to compare. Not a secret and not the
/// pairing token (§3.6): a random UUID minted on first launch and kept in user defaults.
public enum DeviceIdentity {
    static let key = "studybot.deviceID"

    /// The id for this device, minted on first call. A Debug build honours `STUDYBOT_DEVICE_ID`
    /// so two instances on one Mac can stand in for two Macs in the sync drill (§3.11).
    public static func current(defaults: UserDefaults = .standard) -> String {
        #if DEBUG
            if let override = ProcessInfo.processInfo.environment["STUDYBOT_DEVICE_ID"], !override.isEmpty {
                return override
            }
        #endif
        if let existing = defaults.string(forKey: key), !existing.isEmpty {
            return existing
        }
        let fresh = UUID().uuidString.lowercased()
        defaults.set(fresh, forKey: key)
        return fresh
    }
}
