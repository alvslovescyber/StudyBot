import Foundation
import StudyBotCore
import StudyBotKit
import Testing

/// §3.12 row "Rate limiter": the bucket refills correctly and the client's Retrier honours
/// Retry-After with jitter.
@Suite("TokenBucket and Retrier")
struct RateLimitTests {
    private let t0 = Date(timeIntervalSince1970: 1_790_000_000)

    @Test("ten per minute allows a burst of ten, then refuses with the wait, then refills")
    func bucket() {
        var bucket = TokenBucket(perMinute: 10, now: t0)
        for _ in 0..<10 {
            #expect(bucket.take(at: t0).allowed)
        }
        let refused = bucket.take(at: t0)
        #expect(!refused.allowed)
        #expect(abs(refused.retryAfter - 6) < 0.001, "one token every six seconds")
        #expect(!bucket.take(at: t0.addingTimeInterval(3)).allowed)
        #expect(bucket.take(at: t0.addingTimeInterval(6.01)).allowed)
        // A long pause refills to capacity and no further.
        var rested = bucket
        _ = rested.take(at: t0.addingTimeInterval(3_600))
        #expect(rested.tokens < 10 && rested.tokens >= 9)
    }

    @Test("the retrier backs off exponentially with jitter, honours Retry-After, and gives up")
    func retrier() {
        let retrier = Retrier(maximumAttempts: 3, baseDelay: 0.5, maximumDelay: 30)
        #expect(retrier.delay(beforeAttempt: 1, retryAfter: nil, random: 0) == 0.5)
        #expect(retrier.delay(beforeAttempt: 2, retryAfter: nil, random: 0) == 1.0)
        #expect(retrier.delay(beforeAttempt: 3, retryAfter: nil, random: 1) == 2.0 * 1.25)
        #expect(retrier.delay(beforeAttempt: 2, retryAfter: 7, random: 0) == 7, "Retry-After wins")
        #expect(retrier.delay(beforeAttempt: 4, retryAfter: nil) == nil, "stops after the maximum")
        let capped = Retrier(maximumAttempts: 10, baseDelay: 8, maximumDelay: 30)
        #expect(capped.delay(beforeAttempt: 6, retryAfter: nil, random: 0) == 30)
    }
}
