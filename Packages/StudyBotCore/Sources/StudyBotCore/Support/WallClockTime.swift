/// A time of day in local wall-clock terms, such as 07:00 for the morning plan.
///
/// The spec types `morningPlanTime` as `Date`, but §4 also requires that anything
/// scheduled by wall-clock time is stored in wall-clock terms so it does not drift by an
/// hour when British Summer Time starts or ends. A `Date` is an instant and cannot express
/// "seven in the morning, whatever the offset is that day", so this type does instead.
public struct WallClockTime: Codable, Hashable, Sendable, Comparable {
    /// Hour of the day, 0–23.
    public var hour: Int
    /// Minute of the hour, 0–59.
    public var minute: Int

    public init(hour: Int, minute: Int = 0) {
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)
    }

    /// Minutes since midnight, for ordering and arithmetic.
    public var minutesSinceMidnight: Int { hour * 60 + minute }

    public static func < (lhs: WallClockTime, rhs: WallClockTime) -> Bool {
        lhs.minutesSinceMidnight < rhs.minutesSinceMidnight
    }
}
