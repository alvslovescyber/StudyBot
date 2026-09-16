import Foundation
import StudyBotCore
import Testing

/// §3.12 row "Sync merge": clean push, sequential edit, conflicting edit resolves to the later
/// `updatedAt`, the loser is archived in both directions, a replayed push is idempotent, and
/// a same-instant tie resolves identically whichever side asks.
@Suite("SyncMerge — the server's decision for one pushed record")
struct SyncMergeTests {
    private let t0 = Date(timeIntervalSince1970: 1_790_000_000)
    private let id = UUID()
    private let macA = "1f0c-air"
    private let macB = "9a3f-mini"

    private func push(at offset: TimeInterval, base: Int, title: String = "x") -> SyncRecord {
        SyncRecord(
            type: "assignment", id: id, baseVersion: base, updatedAt: t0.addingTimeInterval(offset),
            fields: ["title": .string(title)])
    }

    private func server(version: Int, at offset: TimeInterval, device: String) -> ServerRecordState {
        ServerRecordState(
            type: "assignment", id: id, version: version, seq: version * 10,
            updatedAt: t0.addingTimeInterval(offset), deviceID: device, fields: ["title": "server"])
    }

    @Test("a record the server has never seen is accepted with nothing to archive")
    func freshRecord() {
        #expect(
            SyncMerge.decide(incoming: push(at: 0, base: 0), from: macA, against: nil)
                == .accept(replacing: nil))
    }

    @Test("an edit based on the current server version is a plain sequential write")
    func sequentialEdit() {
        let existing = server(version: 7, at: 0, device: macB)
        let outcome = SyncMerge.decide(incoming: push(at: 60, base: 7), from: macA, against: existing)
        #expect(outcome == .accept(replacing: nil))
    }

    @Test("a concurrent edit with the later updatedAt wins and the server version is archived")
    func clientWinsConcurrent() {
        let existing = server(version: 8, at: 30, device: macB)
        let outcome = SyncMerge.decide(incoming: push(at: 60, base: 7), from: macA, against: existing)
        #expect(outcome == .accept(replacing: existing))
    }

    @Test("a concurrent edit with the earlier updatedAt loses and is reported as a conflict")
    func serverWinsConcurrent() {
        let existing = server(version: 8, at: 90, device: macB)
        let outcome = SyncMerge.decide(incoming: push(at: 60, base: 7), from: macA, against: existing)
        #expect(outcome == .reject)
    }

    @Test("a same-millisecond tie resolves on deviceID, lower wins, from either side")
    func sameInstantTie() {
        // Mac A (lower id) and Mac B edit at the same instant; each pushes against version 7.
        // Whichever arrives second, A's version ends up current.
        let bArrivedFirst = server(version: 8, at: 60, device: macB)
        #expect(
            SyncMerge.decide(incoming: push(at: 60, base: 7), from: macA, against: bArrivedFirst)
                == .accept(replacing: bArrivedFirst))
        let aArrivedFirst = server(version: 8, at: 60, device: macA)
        #expect(
            SyncMerge.decide(incoming: push(at: 60, base: 7), from: macB, against: aArrivedFirst) == .reject)
    }

    @Test("the same write arriving again is already applied, not a conflict and not a new version")
    func replayedPush() {
        // A pushed at t+60, the server stored it as version 8, and the response was lost.
        let existing = server(version: 8, at: 60, device: macA)
        let outcome = SyncMerge.decide(incoming: push(at: 60, base: 7), from: macA, against: existing)
        #expect(outcome == .alreadyApplied)
    }

    @Test("identical content from another device is agreement, not a conflict")
    func identicalContent() {
        // Both Macs imported the same calendar: same fields, different writers and instants.
        let existing = ServerRecordState(
            type: "module", id: id, version: 1, seq: 10, updatedAt: t0, deviceID: macB,
            fields: ["code": "COM1018DA", "name": "Programming"])
        var incoming = push(at: 5, base: 0, title: "x")
        incoming.fields = ["code": "COM1018DA", "name": "Programming", "credits": .null]
        #expect(SyncMerge.decide(incoming: incoming, from: macA, against: existing) == .alreadyApplied)
        incoming.fields["name"] = "Programming 1"
        #expect(
            SyncMerge.decide(incoming: incoming, from: macA, against: existing)
                == .accept(replacing: existing))
    }

    @Test("a tombstone is an ordinary write and follows the same rules")
    func tombstone() {
        var deletion = push(at: 60, base: 7)
        deletion.deletedAt = t0.addingTimeInterval(60)
        let existing = server(version: 7, at: 0, device: macB)
        #expect(
            SyncMerge.decide(incoming: deletion, from: macA, against: existing) == .accept(replacing: nil))
    }

    @Test("a client whose base is ahead of the server (server restored from backup) is judged on updatedAt")
    func serverRestoredFromBackup() {
        // The server lost versions 8–12; the client is at 12 and edited later than anything left.
        let existing = server(version: 7, at: 0, device: macB)
        let outcome = SyncMerge.decide(incoming: push(at: 600, base: 12), from: macA, against: existing)
        #expect(outcome == .accept(replacing: existing))
    }

    @Test("the client-side check agrees with the server: a local edit keeps only when it would win")
    func clientSideAgrees() {
        var local = SyncMetadata.new(id: id, at: t0, deviceID: macA)
        local.updatedAt = t0.addingTimeInterval(60)
        var change = push(at: 60, base: 8)
        change.version = 8
        change.deviceID = macB
        #expect(SyncMerge.localEditWins(local: local, over: change))
        change.updatedAt = t0.addingTimeInterval(61)
        #expect(!SyncMerge.localEditWins(local: local, over: change))
    }

    @Test("the refusal and pairing DTOs round-trip on the wire")
    func newDTOs() throws {
        let refusal = SyncRefusal(requiredVersion: 2, serverVersion: 3)
        #expect(try SyncCoding.decode(SyncRefusal.self, from: SyncCoding.encode(refusal)) == refusal)
        let pair = PairRequest(code: "apple brook candle dune ember frost", deviceName: "MacBook Air")
        #expect(try SyncCoding.decode(PairRequest.self, from: SyncCoding.encode(pair)) == pair)
        let archived = ArchivedRecord(id: "c_1", record: push(at: 1, base: 1), archivedAt: t0)
        #expect(try SyncCoding.decode(ArchivedRecord.self, from: SyncCoding.encode(archived)) == archived)
        #expect(SyncSchema.header == "X-StudyBot-Schema")
    }
}
