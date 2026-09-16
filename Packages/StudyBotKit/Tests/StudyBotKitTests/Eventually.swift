import Foundation

/// Polls `condition` until it holds or `timeout` passes, and says which.
///
/// Debounced work (a save once typing pauses, a sync once writes settle) lands whenever the
/// scheduler gets to it, and on a busy CI runner that is often well after the delay itself.
/// Waiting for the outcome, rather than sleeping for a guess at it, keeps these tests honest
/// on any machine. A fixed sleep remains the right tool only for proving that something did
/// *not* happen once its delay has passed.
@MainActor
func eventually(
    within timeout: Duration = .seconds(5), every interval: Duration = .milliseconds(5),
    _ condition: @MainActor () async throws -> Bool
) async rethrows -> Bool {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)
    while true {
        if try await condition() { return true }
        if clock.now >= deadline { return false }
        try? await Task.sleep(for: interval)
    }
}
