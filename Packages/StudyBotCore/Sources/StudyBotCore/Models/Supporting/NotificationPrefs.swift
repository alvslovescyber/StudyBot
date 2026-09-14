/// Which notification types are on (spec §4 Supporting types, §11). All are off until the
/// user turns one on; permission is requested at that moment, never at launch (§6.0).
public struct NotificationPrefs: Codable, Hashable, Sendable {
    public var deadlines: Bool
    public var morningPlan: Bool
    /// Local wall-clock time for the morning plan, so it does not drift across BST changes.
    public var morningPlanTime: WallClockTime
    public var otjPacing: Bool
    public var gradeReturned: Bool
    public var sessionStarting: Bool
    public var sundayReview: Bool
    public var sundayReviewEmail: Bool

    public init(
        deadlines: Bool = false,
        morningPlan: Bool = false,
        morningPlanTime: WallClockTime = WallClockTime(hour: 7),
        otjPacing: Bool = false,
        gradeReturned: Bool = false,
        sessionStarting: Bool = false,
        sundayReview: Bool = false,
        sundayReviewEmail: Bool = false
    ) {
        self.deadlines = deadlines
        self.morningPlan = morningPlan
        self.morningPlanTime = morningPlanTime
        self.otjPacing = otjPacing
        self.gradeReturned = gradeReturned
        self.sessionStarting = sessionStarting
        self.sundayReview = sundayReview
        self.sundayReviewEmail = sundayReviewEmail
    }

    /// Everything off, morning plan at 07:00.
    public static let allOff = NotificationPrefs()
}
