import StudyBotCore
import StudyBotKit
import StudyBotUI
import SwiftUI

/// Today (§6.1). Two columns from 1200pt: the spine on the left (date, block, next deadline,
/// the plan, this week's hours) and the context on the right (questions to ask, recent notes,
/// the term at a glance); one column below that. The term strip runs full width beneath.
/// Nothing here is a mockup: before induction the plan is one line, the questions panel says
/// what will fill it, and every number at a glance is a true zero.
struct TodayView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.sbScale) private var scale

    /// The width at which Today becomes two columns.
    static let twoColumnWidth: CGFloat = 1200
    /// The content never grows past this; on a wide screen it sits left, as text does.
    static let maximumWidth: CGFloat = 1180

    var body: some View {
        GeometryReader { geometry in
            // A ScrollView: §6.1 puts the term strip below the fold and §16 needs the largest
            // accessibility text sizes to fit without clipping on a 13-inch screen.
            ScrollView {
                content(twoColumns: geometry.size.width >= Self.twoColumnWidth && !scale.isAccessibility)
            }
        }
        .background(SBColor.surface)
        .task { model.refreshPlan() }
        .onChange(of: model.assignments?.assignments) { _, _ in model.refreshPlan() }
        .onChange(of: model.notes?.allSessions) { _, _ in model.refreshPlan() }
        .onChange(of: model.hours?.entries) { _, _ in model.refreshPlan() }
    }

    private func content(twoColumns: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if twoColumns {
                HStack(alignment: .top, spacing: scale(56)) {
                    spine.frame(maxWidth: .infinity, alignment: .leading)
                    context.frame(width: scale(400), alignment: .leading)
                }
                .padding(.top, 24)
            } else {
                spine.padding(.top, 24)
                context.padding(.top, 40)
            }

            if let strip = model.termStrip {
                TermStripSection(strip: strip).padding(.top, 48)
            }
        }
        .frame(maxWidth: scale(Self.maximumWidth), alignment: .leading)
        .padding(.top, 28)
        .padding(.horizontal, SBSpacing.detailOuter)
        .padding(.bottom, 60)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(RelativeDate.longDay(model.now()))
                .sbType(SBType.title)
                .foregroundStyle(SBColor.textPrimary)

            // The only sync UI outside Settings (§3.4): one quiet line, and only when it matters.
            if let notice = model.sync?.todayNotice {
                Text(notice)
                    .sbFont(12)
                    .foregroundStyle(SBColor.textTertiary)
                    .padding(.top, 6)
            }
            // §16: under 2 GB once, under 500 MB until there is room.
            if let disk = model.disk, let notice = disk.todayNotice {
                HStack(spacing: scale(8)) {
                    Text(notice)
                        .sbFont(12, weight: disk.level == .critical ? .medium : .regular)
                        .foregroundStyle(disk.level == .critical ? SBColor.danger : SBColor.textSecondary)
                    if disk.noticeIsDismissible {
                        Button("Dismiss") { disk.dismissLowWarning() }
                            .buttonStyle(.plain)
                            .sbFont(12)
                            .foregroundStyle(SBColor.accent)
                    }
                }
                .padding(.top, 6)
            }
        }
    }

    // MARK: Columns

    private var spine: some View {
        VStack(alignment: .leading, spacing: 36) {
            if let banner = model.blockBanner {
                BlockBannerView(banner: banner).padding(.bottom, -10)
            }
            NextDeadlineSection()
            if let plan = model.plan, plan.isVisible || plan.isProposed {
                PlanSection(plan: plan)
            }
            if let hours = model.hours {
                HoursSection(hours: hours)
            }
        }
    }

    private var context: some View {
        VStack(alignment: .leading, spacing: 36) {
            QuestionsSection()
            RecentNotesSection()
            if let glance = model.termGlance {
                GlanceSection(glance: glance, termTitle: model.termStrip?.title ?? "This term")
            }
        }
    }
}

/// A Today section: 12pt semibold heading in `textSecondary`, an optional note on the right,
/// then the content. Sections separate with space, not rules (§9).
struct TodaySection<Content: View>: View {
    let title: String
    var note: String?
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .sbFont(12, weight: .semibold)
                    .foregroundStyle(SBColor.textSecondary)
                Spacer(minLength: 0)
                if let note {
                    Text(note)
                        .sbFont(12)
                        .foregroundStyle(SBColor.textTertiary)
                }
            }
            content()
        }
        .accessibilityElement(children: .contain)
    }
}

/// One quiet line for a section with nothing in it yet: what will fill it (Today, "Empty
/// states before data exists"). No illustration.
struct TodayEmptyLine: View {
    let text: String

    var body: some View {
        Text(text)
            .sbFont(13)
            .foregroundStyle(SBColor.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
