import Foundation
import StudyBotCore
import Testing

@Suite("LastWriteWins — §3.4 rule with the §4 deterministic tie-break")
struct LastWriteWinsTests {
    private let t0 = Date(timeIntervalSince1970: 1_790_000_000)
    private let id = UUID()

    private func meta(at offset: TimeInterval, device: String, version: Int = 0) -> SyncMetadata {
        var meta = SyncMetadata.new(id: id, at: t0, deviceID: device)
        meta.updatedAt = t0.addingTimeInterval(offset)
        meta.version = version
        return meta
    }

    @Test("the later updatedAt wins regardless of device")
    func laterWins() {
        let older = meta(at: 0, device: "aaaa")
        let newer = meta(at: 0.001, device: "zzzz")
        #expect(LastWriteWins.winner(older, newer) == .second)
        #expect(LastWriteWins.winner(newer, older) == .first)
        #expect(LastWriteWins.resolve(older, newer) == newer)
    }

    @Test("equal updatedAt resolves on deviceID, lower wins, on both machines alike")
    func tieBreakOnDevice() {
        let macA = meta(at: 5, device: "1F0C-MacBook-Air")
        let macB = meta(at: 5, device: "9A3F-Mac-mini")
        // The same answer whichever side asks the question.
        #expect(LastWriteWins.winner(macA, macB) == .first)
        #expect(LastWriteWins.winner(macB, macA) == .second)
        #expect(LastWriteWins.resolve(macA, macB) == macA)
        #expect(LastWriteWins.resolve(macB, macA) == macA)
    }

    @Test("a known writer beats an unknown writer at the same instant")
    func unknownWriterLoses() {
        let known = meta(at: 5, device: "zzzz")
        let unknown = meta(at: 5, device: "")
        #expect(LastWriteWins.winner(known, unknown) == .first)
        #expect(LastWriteWins.winner(unknown, known) == .second)
    }

    @Test("same instant, same device: the higher server version wins, then the first argument")
    func sameDeviceFallsBackToVersion() {
        let synced = meta(at: 5, device: "aaaa", version: 4)
        let local = meta(at: 5, device: "aaaa", version: 0)
        #expect(LastWriteWins.winner(local, synced) == .second)
        #expect(LastWriteWins.winner(synced, local) == .first)
        let same = meta(at: 5, device: "aaaa", version: 4)
        #expect(LastWriteWins.winner(synced, same) == .first)
    }

    @Test("deviceID travels with an edit and older rows decode with an empty writer")
    func deviceIDPlumbing() throws {
        var meta = SyncMetadata.new(at: t0, deviceID: "mac-1")
        meta.markEdited(at: t0.addingTimeInterval(1), by: "mac-2")
        #expect(meta.deviceID == "mac-2")
        meta.markEdited(at: t0.addingTimeInterval(2))
        #expect(meta.deviceID == "mac-2", "nil keeps the current writer")

        let legacy = """
            {"id":"\(id.uuidString)","createdAt":0,"updatedAt":0,"version":0,"baseVersion":0,"seq":0,"dirty":true}
            """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let decoded = try decoder.decode(SyncMetadata.self, from: Data(legacy.utf8))
        #expect(decoded.deviceID == "")
    }
}
