import Foundation
import StudyBotCore
import Testing

@Suite("SyncMetadata")
struct SyncMetadataTests {
    private let t0 = Date(timeIntervalSince1970: 1_790_000_000)
    private var t1: Date { t0.addingTimeInterval(60) }
    private var t2: Date { t0.addingTimeInterval(120) }

    @Test("a new record is version 0, unsynced, dirty and not deleted")
    func newRecordDefaults() {
        let meta = SyncMetadata.new(at: t0)
        #expect(meta.version == 0)
        #expect(meta.baseVersion == 0)
        #expect(meta.seq == 0)
        #expect(meta.dirty)
        #expect(!meta.isDeleted)
        #expect(meta.createdAt == t0)
        #expect(meta.updatedAt == t0)
    }

    @Test("an edit bumps updatedAt and marks dirty without touching baseVersion")
    func editBumpsUpdatedAt() {
        var meta = SyncMetadata.new(at: t0)
        meta.acknowledge(version: 4, seq: 100)
        meta.markEdited(at: t1)
        #expect(meta.updatedAt == t1)
        #expect(meta.dirty)
        #expect(meta.baseVersion == 4)
        #expect(meta.version == 4)
    }

    @Test("acknowledging a push sets version, baseVersion and seq and clears dirty")
    func acknowledgeClearsDirty() {
        var meta = SyncMetadata.new(at: t0)
        meta.acknowledge(version: 1, seq: 4839)
        #expect(meta.version == 1)
        #expect(meta.baseVersion == 1)
        #expect(meta.seq == 4839)
        #expect(!meta.dirty)
    }

    @Test("deletion is a tombstone and a second delete keeps the first timestamp")
    func deleteIsIdempotentTombstone() {
        var meta = SyncMetadata.new(at: t0)
        meta.markDeleted(at: t1)
        meta.markDeleted(at: t2)
        #expect(meta.deletedAt == t1)
        #expect(meta.isDeleted)
        #expect(meta.updatedAt == t2)
        #expect(meta.dirty)
    }

    @Test("the id survives a Codable round trip unchanged")
    func codableRoundTrip() throws {
        let original = SyncMetadata.new(at: t0)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SyncMetadata.self, from: data)
        #expect(decoded == original)
        #expect(decoded.id == original.id)
    }
}
