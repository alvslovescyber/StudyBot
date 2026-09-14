import Foundation

/// The programme calendar shipped inside the app (spec §4A, "Import behaviour").
///
/// The ICS is a package resource so the app can import it on first launch with no
/// file picker. A test asserts the bundled copy is byte-identical to the file in the
/// repo root, so the two cannot drift apart silently.
public enum BundledProgrammeCalendar {
    /// The file name of the bundled calendar, as issued by the university.
    public static let fileName = "DTS_L6_Sept_2026_intake.ics"

    /// Reasons the bundled calendar could not be read. Should never happen in a
    /// correctly built app; surfaced so first-run can fail legibly rather than crash.
    public enum Error: Swift.Error, Equatable {
        case resourceMissing(String)
    }

    /// Location of the bundled ICS inside the package's resource bundle.
    public static func url() throws(Error) -> URL {
        guard let url = Bundle.module.url(forResource: fileName, withExtension: nil) else {
            throw .resourceMissing(fileName)
        }
        return url
    }

    /// The raw bytes of the bundled ICS.
    public static func data() throws -> Data {
        try Data(contentsOf: url())
    }
}
