import Foundation

/// Backoff with jitter that honours `Retry-After` (§3.3, §3.7). Pure: it decides how long to
/// wait; the caller sleeps.
public struct Retrier: Sendable {
    public let maximumAttempts: Int
    public let baseDelay: TimeInterval
    public let maximumDelay: TimeInterval

    public init(maximumAttempts: Int = 3, baseDelay: TimeInterval = 0.5, maximumDelay: TimeInterval = 30) {
        self.maximumAttempts = maximumAttempts
        self.baseDelay = baseDelay
        self.maximumDelay = maximumDelay
    }

    /// The wait before attempt `attempt` (1-based, after a failure), or nil to stop. A server's
    /// `retryAfter` wins over the exponential curve; jitter is 0 to 25% on top, from `random`.
    public func delay(
        beforeAttempt attempt: Int, retryAfter: TimeInterval?, random: Double = Double.random(in: 0..<1)
    )
        -> TimeInterval?
    {
        guard attempt <= maximumAttempts else { return nil }
        let base = retryAfter ?? min(baseDelay * pow(2, Double(attempt - 1)), maximumDelay)
        return base * (1 + 0.25 * min(max(random, 0), 1))
    }
}
