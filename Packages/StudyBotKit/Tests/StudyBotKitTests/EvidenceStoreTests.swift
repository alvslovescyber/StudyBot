import Foundation
import StudyBotCore
import StudyBotKit
import Testing

@MainActor
@Suite("EvidenceStore — four fields, thirty seconds")
struct EvidenceStoreTests {
    private nonisolated static let t0 = SyncClient.t0

    @Test("a draft with codes becomes evidence with pending KSB codes, dated by day")
    func create() async throws {
        let records = InMemoryRecordStore()
        let store = EvidenceStore(store: records, deviceID: "air", now: { Self.t0 })
        var draft = EvidenceStore.Draft(date: Self.t0.addingTimeInterval(3_600 * 15), source: .lecture)
        draft.title = "Sprint review"
        draft.summary = "Led the review for the payments team."
        draft.ksbCodes = "k3, s12 K3  b4"
        let created = try #require(await store.create(draft))
        #expect(created.pendingKSBCodes == ["K3", "S12", "B4"])
        #expect(created.ksbIDs.isEmpty)
        #expect(created.isWorkConfidential == false, "a lecture is not work")
        #expect(created.date == UKCalendar.startOfDay(draft.date))
        #expect(store.items.map(\.id) == [created.id])
        #expect(
            try await records.fetch(Evidence.self, id: created.id)?.value.pendingKSBCodes == [
                "K3", "S12", "B4",
            ])
    }

    @Test("a blank draft is refused with a reason, and work defaults to confidential")
    func validation() async {
        let store = EvidenceStore(store: InMemoryRecordStore(), deviceID: "air", now: { Self.t0 })
        let blank = EvidenceStore.Draft(date: Self.t0)
        #expect(await store.create(blank) == nil)
        #expect(store.lastError?.isEmpty == false)
        var work = EvidenceStore.Draft(date: Self.t0, source: .workProject)
        work.title = "Incident review"
        work.summary = "Wrote the post-incident report."
        let created = await store.create(work)
        #expect(created?.isWorkConfidential == true)
        if let created {
            await store.delete(created.id)
            #expect(store.items.isEmpty)
        }
    }
}
