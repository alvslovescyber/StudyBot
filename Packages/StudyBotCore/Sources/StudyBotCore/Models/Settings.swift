import Foundation

/// The single settings row (spec §4). Local and synced, so both Macs agree. Its id is
/// fixed so the two devices' rows are the same record.
public struct Settings: Syncable {
    public static let recordType = "settings"

    /// The one and only settings record id.
    public static let singletonID = StableID.uuid(namespace: StableID.Namespace.settings, name: "singleton")

    public var sync: SyncMetadata
    /// Default 6. Confirm the actual requirement with the provider (§6.5).
    public var targetOTJHoursPerWeek: Double
    public var gradeBands: [GradeBand]
    /// Money is an integer in pence, never a Double (§3.13).
    public var monthlyAIBudgetPence: Int
    public var notificationPrefs: NotificationPrefs
    /// Configurable until Exeter's format is known.
    public var otjExportMapping: [ExportColumn]
    /// Year 3 specialism module codes, once chosen.
    public var specialismChoices: [String]
    /// The Assignments list scope (§6.2), persisted here.
    public var assignmentListScope: AssignmentListScope

    public init(
        sync: SyncMetadata,
        targetOTJHoursPerWeek: Double = 6,
        gradeBands: [GradeBand] = GradeBand.defaults,
        monthlyAIBudgetPence: Int = 800,
        notificationPrefs: NotificationPrefs = .allOff,
        otjExportMapping: [ExportColumn] = ExportColumn.defaults,
        specialismChoices: [String] = [],
        assignmentListScope: AssignmentListScope = .currentTerm
    ) {
        self.sync = sync
        self.targetOTJHoursPerWeek = targetOTJHoursPerWeek
        self.gradeBands = gradeBands
        self.monthlyAIBudgetPence = monthlyAIBudgetPence
        self.notificationPrefs = notificationPrefs
        self.otjExportMapping = otjExportMapping
        self.specialismChoices = specialismChoices
        self.assignmentListScope = assignmentListScope
    }

    /// Fresh defaults created at `now`. The £8 AI cap is the figure §9's error copy uses.
    public static func defaults(at now: Date) -> Settings {
        Settings(sync: SyncMetadata.new(id: singletonID, at: now))
    }
}
