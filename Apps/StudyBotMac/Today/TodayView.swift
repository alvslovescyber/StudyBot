import StudyBotCore
import StudyBotKit
import StudyBotUI
import SwiftUI

/// Today (§6.1), the parts that exist with real data on day one: the date, the block banner
/// when a block is within 14 days, the next deadline, and below the fold the term strip. The
/// plan and off-the-job arrive with their milestones. Nothing here is a mockup: an untitled
/// stub shows as one.
struct TodayView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        // A ScrollView: §6.1 puts the term strip below the fold and §16 needs the largest
        // accessibility text sizes to fit without clipping on a 13-inch screen.
        ScrollView {
            todayContent
        }
        .background(SBColor.surface)
    }

    private var todayContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(RelativeDate.longDay(model.now()))
                .sbType(SBType.title)
                .foregroundStyle(SBColor.textPrimary)

            // The only sync UI outside Settings (§3.4): one quiet line, and only when it matters.
            if let notice = model.sync?.todayNotice {
                Text(notice)
                    .font(.system(size: 12))
                    .foregroundStyle(SBColor.textTertiary)
                    .padding(.top, 6)
            }

            if let banner = blockBanner {
                blockBannerView(banner)
                    .padding(.top, 18)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Next deadline")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SBColor.textSecondary)
                nextDeadlineCard
            }
            .padding(.top, 26)

            if let strip = termStrip {
                termStripSection(strip)
                    .padding(.top, 36)
            }
        }
        .frame(maxWidth: 656, alignment: .leading)
        .padding(.top, 28)
        .padding(.horizontal, SBSpacing.detailOuter)
        .padding(.bottom, 60)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Block banner

    private struct Banner {
        let title: String
        let dates: String
    }

    private var blockBanner: Banner? {
        guard let calendar = model.termCalendar else { return nil }
        let today = LocalDay(model.now())
        guard let block = calendar.currentOrNextBlock(from: today),
            let days = calendar.daysToNextBlock(from: today),
            days <= 14
        else { return nil }
        let name = "Block \(block.number)"
        let title: String
        switch days {
        case 0: title = "\(name) is on now"
        case 1: title = "\(name) starts tomorrow"
        default: title = "\(name) starts in \(days) days"
        }
        return Banner(
            title: title,
            dates: RelativeDate.dayRange(block.start.date, block.end.date, relativeTo: model.now()))
    }

    private func blockBannerView(_ banner: Banner) -> some View {
        HStack {
            Text(banner.title)
                .font(.system(size: 13, weight: .medium))
            Spacer()
            Text("\(banner.dates) →")
                .font(.system(size: 12))
        }
        .foregroundStyle(SBColor.accent)
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(SBColor.accentSoft)
        .overlay(
            RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous).strokeBorder(SBColor.border)
        )
        .clipShape(RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous))
    }

    // MARK: Term strip (§9 "Signature details")

    private var termStrip: TermStrip? {
        guard let calendar = model.termCalendar else { return nil }
        let dueDates = model.assignments?.assignments.compactMap(\.dueDate) ?? []
        return TermStrip(
            calendar: calendar, events: model.events, submissionDates: dueDates, today: LocalDay(model.now()))
    }

    private func termStripSection(_ strip: TermStrip) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(strip.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SBColor.textSecondary)
                Spacer()
                Text(strip.caption)
                    .font(.system(size: 12))
                    .foregroundStyle(SBColor.textTertiary)
            }
            TermStripView(strip)
        }
    }

    // MARK: Next deadline

    private var nextAssignment: Assignment? {
        let today = LocalDay(model.now())
        let incomplete = model.assignments?.assignments.filter(\.isIncomplete) ?? []
        return
            incomplete
            .filter { $0.dueDate.map { LocalDay($0) >= today } ?? false }
            .min { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
            ?? incomplete.filter { $0.dueDate != nil }.max {
                ($0.dueDate ?? .distantPast) < ($1.dueDate ?? .distantPast)
            }
    }

    /// The card's second line (§6.1): the honest number of working days, then what the
    /// assignment is still missing. The title already carries the date, so it is not repeated.
    /// Overdue stays "overdue by", which is the one case where the raw day count is the point.
    private func detailLine(for assignment: Assignment, module: Module?) -> String {
        var parts: [String] = []
        if let code = module?.code {
            parts.append(code)
        }
        if let due = assignment.dueDate {
            if UKCalendar.days(from: model.now(), to: due) < 0 {
                parts.append(RelativeDate.deadline(due, relativeTo: model.now()))
            } else {
                let working = WorkingDays(events: model.events).count(from: model.now(), until: due)
                parts.append(RelativeDate.workingDays(working))
            }
        }
        if assignment.isCalendarStub {
            parts.append(module == nil ? "module and brief arrive from ELE2" : "brief arrives from ELE2")
        } else {
            if let limit = assignment.wordLimit {
                parts.append(RelativeDate.wordCount(limit))
            }
            parts.append(StatusIcon.label(for: assignment.status).lowercased())
        }
        return parts.joined(separator: " · ")
    }

    private func isOverdue(_ assignment: Assignment) -> Bool {
        guard let due = assignment.dueDate else { return false }
        return UKCalendar.days(from: model.now(), to: due) < 0
    }

    @ViewBuilder
    private var nextDeadlineCard: some View {
        if let assignment = nextAssignment, let store = model.assignments {
            Button {
                model.selection = .assignments
                model.open(assignment)
            } label: {
                HStack(alignment: .top, spacing: 11) {
                    StatusIcon(assignment.status, size: 15).padding(.top, 2)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(assignment.title)
                            .font(.system(size: 14, weight: .medium))
                            .italic(assignment.isCalendarStub)
                            .foregroundStyle(
                                isOverdue(assignment)
                                    ? SBColor.danger
                                    : assignment.isCalendarStub ? SBColor.textSecondary : SBColor.textPrimary)
                        Text(detailLine(for: assignment, module: store.module(for: assignment)))
                            .font(.system(size: 12))
                            .foregroundStyle(isOverdue(assignment) ? SBColor.danger : SBColor.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .sbCard()
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            EmptyState("No submissions this term. Show all 30.", actionTitle: "Show all") {
                model.assignments?.scope = .all
                model.selection = .assignments
            }
        }
    }
}
