/// The wire schema version carried by every sync DTO (spec §3.5, §3.10a).
///
/// The server accepts the current version and one behind. A client more than one
/// version behind is refused with `409` and stops syncing without losing anything.
/// Bump `current` only alongside a migration and a row in the §3.12 migrations tests.
public enum SyncSchema {
    /// The schema version this build speaks.
    public static let current = 1

    /// The header a client sends its schema version in on requests that have no body
    /// (`GET /v1/sync`). `POST /v1/sync` carries it in the body as well.
    public static let header = "X-StudyBot-Schema"

    /// The oldest schema version a server on `current` still accepts.
    public static var oldestAccepted: Int { max(1, current - 1) }

    /// Whether a server on `current` accepts a client speaking `version`.
    public static func accepts(_ version: Int) -> Bool {
        version >= oldestAccepted && version <= current
    }
}
