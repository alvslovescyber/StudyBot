import StudyBotCore
import StudyBotKit
import StudyBotUI
import SwiftUI

/// Today (§6.1), the parts that exist with real data on day one: the date, the block banner
/// when a block is within 14 days, and the next deadline. The plan, off-the-job and the term
/// strip arrive with their milestones. Nothing here is a mockup: an untitled stub shows as one.
struct TodayView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        // A plain column, not a ScrollView: see docs/decisions.md, "Today is not a ScrollView yet".
        VStack(alignment: .leading, spacing: 0) {
            todayContent
            Spacer(minLength: 0)
        }
        .background(SBColor.surface)
    }

    private var todayContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text(RelativeDate.longDay(model.now()))
                    .sbType(SBType.title)
                    .foregroundStyle(SBColor.textPrimary)

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
            }
            .frame(maxWidth: 656, alignment: .leading)
            .padding(.top, 28)
            .padding(.horizontal, SBSpacing.detailOuter)
            .padding(.bottom, 60)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
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

    /// Today is the one place the exact count matters, so it is always a number of days here.
    private func dueWording(_ due: Date) -> String {
        let days = UKCalendar.days(from: model.now(), to: due)
        switch days {
        case 0: return "due today"
        case 1: return "due tomorrow"
        case ..<0: return "overdue by \(-days) days"
        default: return "due in \(days) days"
        }
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
                                assignment.isCalendarStub ? SBColor.textSecondary : SBColor.textPrimary)
                        HStack(spacing: 6) {
                            if let module = store.module(for: assignment) {
                                Text(module.code)
                                Text("·")
                            } else {
                                Text("no module yet")
                                Text("·")
                            }
                            if let due = assignment.dueDate {
                                Text(dueWording(due))
                                Text("·")
                                Text(RelativeDate.fullDate(due))
                                Text("·")
                            }
                            Text(StatusIcon.label(for: assignment.status).lowercased())
                        }
                        .font(.system(size: 12))
                        .foregroundStyle(SBColor.textSecondary)
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
