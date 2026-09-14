import StudyBotCore
import Testing

@Suite("SyncSchema")
struct SyncSchemaTests {
    @Test("the current version and one behind are accepted; two behind is refused")
    func acceptanceWindow() {
        #expect(SyncSchema.accepts(SyncSchema.current))
        #expect(SyncSchema.accepts(SyncSchema.current - 1) == (SyncSchema.current > 1))
        #expect(!SyncSchema.accepts(SyncSchema.current - 2))
        #expect(!SyncSchema.accepts(SyncSchema.current + 1))
    }

    @Test("oldestAccepted never drops below 1")
    func oldestAcceptedFloor() {
        #expect(SyncSchema.oldestAccepted >= 1)
    }
}
