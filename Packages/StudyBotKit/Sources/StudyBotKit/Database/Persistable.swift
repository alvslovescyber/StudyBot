import StudyBotCore

/// A Core record type the `Database` can store. Conformances are declared in this package,
/// one per syncable type; the mapping to a SwiftData model is internal, so nothing outside
/// StudyBotKit can name or reach a `@Model` class.
public protocol Persistable: Syncable {}

extension Module: Persistable {}
extension Term: Persistable {}
extension Assignment: Persistable {}
extension Session: Persistable {}
extension Deck: Persistable {}
extension Card: Persistable {}
extension QuizAttempt: Persistable {}
extension KSB: Persistable {}
extension Evidence: Persistable {}
extension OTJEntry: Persistable {}
extension Proposal: Persistable {}
extension Settings: Persistable {}
extension Attachment: Persistable {}
extension AIRun: Persistable {}
