import Foundation

/// The conflict rule (spec §3.4, §4): the later `updatedAt` wins. When two versions carry the
/// same `updatedAt`, the lower `deviceID` wins, lexicographically. Both Macs run this same
/// function over the same two inputs and must reach the same answer, or a record would
/// permanently disagree with itself across machines.
///
/// `updatedAt` is client wall clock and clocks drift, so a fast machine can win an exchange
/// it should have lost. That is accepted for one user (§3.4). What is not accepted is the two
/// machines disagreeing about *who* won, which is what the tie-break removes.
public enum LastWriteWins {
    /// Which side of a comparison won.
    public enum Winner: Equatable, Sendable {
        case first
        case second
    }

    /// Picks the winner between two versions of the same record.
    ///
    /// Order of comparison: later `updatedAt`; then lower `deviceID` (an empty id, meaning
    /// "unknown writer", sorts after every real id so a known writer beats an unknown one);
    /// then higher server `version`, which can only differ when one side has synced. Two
    /// versions equal on all three are the same write, and the first is returned so the
    /// choice is still deterministic.
    public static func winner(_ first: SyncMetadata, _ second: SyncMetadata) -> Winner {
        if first.updatedAt != second.updatedAt {
            return first.updatedAt > second.updatedAt ? .first : .second
        }
        let firstDevice = rank(first.deviceID)
        let secondDevice = rank(second.deviceID)
        if firstDevice != secondDevice {
            return firstDevice < secondDevice ? .first : .second
        }
        if first.version != second.version {
            return first.version > second.version ? .first : .second
        }
        return .first
    }

    /// The winning metadata of the two.
    public static func resolve(_ first: SyncMetadata, _ second: SyncMetadata) -> SyncMetadata {
        winner(first, second) == .first ? first : second
    }

    /// Empty ids sort last, so a record whose writer is known beats one whose writer is not.
    private static func rank(_ deviceID: String) -> String {
        deviceID.isEmpty ? "\u{FFFF}" : deviceID
    }
}
