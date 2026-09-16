import Foundation

/// A token bucket (§3.7 rate limit, §3.3 helpers): `capacity` tokens, refilled continuously
/// at `refillPerSecond`. Pure arithmetic over a clock the caller supplies. In Core so the
/// server's limiter and the client's tests share one definition.
public struct TokenBucket: Hashable, Sendable {
    public let capacity: Double
    public let refillPerSecond: Double
    public private(set) var tokens: Double
    public private(set) var updatedAt: Date

    /// `perMinute` requests, burstable up to `perMinute` at once.
    public init(perMinute: Int, now: Date) {
        capacity = Double(perMinute)
        refillPerSecond = Double(perMinute) / 60
        tokens = capacity
        updatedAt = now
    }

    /// Takes one token if available. On refusal, `retryAfter` is how long until one is.
    public mutating func take(at now: Date) -> (allowed: Bool, retryAfter: TimeInterval) {
        refill(at: now)
        if tokens >= 1 {
            tokens -= 1
            return (true, 0)
        }
        let wait = (1 - tokens) / refillPerSecond
        return (false, wait)
    }

    private mutating func refill(at now: Date) {
        let elapsed = max(now.timeIntervalSince(updatedAt), 0)
        tokens = min(capacity, tokens + elapsed * refillPerSecond)
        updatedAt = now
    }
}
