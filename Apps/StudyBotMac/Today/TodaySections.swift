import StudyBotCore
import StudyBotKit
import StudyBotUI
import SwiftUI

// MARK: Block banner

/// Tapping the banner opens Block mode (§6.1).
struct BlockBannerView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.sbScale) private var scale
    let banner: AppModel.BlockBanner

    var body: some View {
        Button {
            model.enterBlockMode()
        } label: {
            HStack {
                Text(banner.title)
                    .sbFont(13, weight: .medium)
                Spacer()
                Text("\(banner.dates) →")
                    .sbFont(12)
            }
            .foregroundStyle(SBColor.accent)
            .padding(.vertical, scale(12))
            .padding(.horizontal, scale(14))
            .background(SBColor.accentSoft)
            .overlay(
                RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous).strokeBorder(SBColor.border)
            )
            .clipShape(RoundedRectangle(cornerRadius: SBRadius.card, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens Block mode")
    }
}

// MARK: Next deadline

struct NextDeadlineSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        TodaySection(title: "Next deadline") {
            if let assignment = model.nextAssignment, let store = model.assignments {
                Button {
                    model.selection = .assignments
                    model.open(assignment)
                } label: {
                    HStack(alignment: .top, spacing: 11) {
                        StatusIcon(assignment.status, size: 15).padding(.top, 2)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(assignment.title)
                                .italic(assignment.isCalendarStub)
                                .sbFont(14, weight: .medium)
                                .foregroundStyle(
                                    model.isOverdue(assignment)
                                        ? SBColor.danger
                                        : assignment.isCalendarStub
                                            ? SBColor.textSecondary : SBColor.textPrimary)
                            Text(model.deadlineDetail(for: assignment, module: store.module(for: assignment)))
                                .sbFont(12)
                                .foregroundStyle(
                                    model.isOverdue(assignment) ? SBColor.danger : SBColor.textSecondary)
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
}

// MARK: Today's plan (§6.1)

/// A proposal, never an imposition. Three items, accept or dismiss; accepted, it is the day's
/// checklist. Dismissed, it is gone until tomorrow and nobody asks why.
struct PlanSection: View {
    @Environment(\.sbScale) private var scale
    @Bindable var plan: PlanStore

    var body: some View {
        TodaySection(title: "Today's plan", note: plan.isProposed && plan.isVisible ? "Suggested" : nil) {
            if let day = plan.plan, plan.isVisible {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(day.items) { item in
                        row(item, checklist: plan.isAccepted)
                    }
                }
                if plan.isProposed {
                    HStack(spacing: scale(8)) {
                        Spacer(minLength: 0)
                        Btn.primary("Accept plan", icon: "checkmark", size: .small) {
                            withSBAnimation(SBMotion.collapse) { plan.accept() }
                        }
                        Btn.secondary("Dismiss", size: .small) {
                            withSBAnimation(SBMotion.collapse) { plan.dismiss() }
                        }
                    }
                    .padding(.top, 4)
                }
            } else {
                TodayEmptyLine(text: "Nothing to plan yet. Deadlines and last week's notes fill this in.")
            }
        }
    }

    private func row(_ item: PlanItem, checklist: Bool) -> some View {
        Button {
            guard checklist else { return }
            withSBAnimation(SBMotion.collapse) { plan.toggle(item.id) }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: scale(10)) {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .sbFont(13, weight: .regular)
                    .foregroundStyle(item.isDone ? SBColor.statusDone : SBColor.textTertiary)
                Text(item.title)
                    .sbType(SBType.row)
                    .foregroundStyle(item.isDone ? SBColor.textTertiary : SBColor.textPrimary)
                    .strikethrough(item.isDone, color: SBColor.textTertiary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(item.duration)
                    .sbFont(12)
                    .foregroundStyle(SBColor.textTertiary)
                    .monospacedDigit()
            }
            .padding(.vertical, scale(7))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!checklist)
        .accessibilityAddTraits(checklist ? [] : [.isStaticText])
        .accessibilityValue(item.isDone ? "done" : "")
    }
}

// MARK: Off-the-job this week

/// The week bar and the way in. Amber only from Friday when behind (§6.1: mid-week is normal);
/// never red. A failed write says so beneath the bar, once the bar has shrunk back.
struct HoursSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.sbScale) private var scale
    let hours: HoursStore

    var body: some View {
        let today = LocalDay(model.now())
        let week = hours.week(containing: today)
        TodaySection(title: "Off-the-job this week", note: behind(week, today: today) ? "behind" : nil) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(WeekBarView.hours(week.total)) of \(WeekBarView.hours(week.target)) hours")
                    .sbFont(13, weight: .medium)
                    .foregroundStyle(
                        behind(week, today: today) ? SBColor.statusDrafting : SBColor.textPrimary
                    )
                    .monospacedDigit()
                    .contentTransition(.numericText(value: week.total))
                    .sbAnimation(SBMotion.count, value: week.total)
                Spacer(minLength: 0)
                Btn.secondary("Log hours", size: .small) { model.showHoursField() }
                Text("L")
                    .sbFont(11, weight: .medium)
                    .foregroundStyle(SBColor.textTertiary)
                    .padding(.horizontal, scale(5)).padding(.vertical, scale(1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(SBColor.border)
                    )
                    .accessibilityLabel("Shortcut: L")
            }
            WeekBarView(
                days: week.days.map { day in
                    WeekBarView.Day(
                        id: day.day.isoString, letter: String(RelativeDate.weekday(day.day.date).prefix(1)),
                        hours: day.hours, isToday: day.day == today)
                },
                weeklyTarget: week.target
            )
            .frame(maxWidth: scale(360), alignment: .leading)
            .padding(.top, 4)
            if let error = hours.lastError {
                Text(error)
                    .sbFont(12)
                    .foregroundStyle(SBColor.danger)
            }
        }
    }

    private func behind(_ week: HoursStore.Week, today: LocalDay) -> Bool {
        today.isoWeekday >= 5 && week.total < week.target
    }
}

// MARK: Questions to ask

/// Every unanswered `ASK:` line across all sessions, with its session and date. Empty before
/// a block; the most valuable thing in the app during and after one.
struct QuestionsSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.sbScale) private var scale

    var body: some View {
        let questions = model.notes?.allQuestions ?? []
        TodaySection(title: "Questions to ask", note: questions.isEmpty ? nil : "\(questions.count)") {
            if questions.isEmpty {
                TodayEmptyLine(text: "Questions you mark with ASK: during a session collect here.")
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(questions) { question in
                        Button {
                            model.openSession(id: question.sessionID)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(question.text)
                                    .sbType(SBType.row)
                                    .foregroundStyle(SBColor.textPrimary)
                                    .lineLimit(2)
                                Text(
                                    "\(question.sessionTitle) · \(RelativeDate.absolute(question.day.date, relativeTo: model.now()))"
                                )
                                .sbFont(12)
                                .foregroundStyle(SBColor.textSecondary)
                                .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, scale(7))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens the session")
                    }
                }
            }
        }
    }
}

// MARK: Recent notes

/// The last five sessions touched, with the first line of each and when.
struct RecentNotesSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.sbScale) private var scale

    var body: some View {
        let recent = model.notes?.recentSessions(limit: 5) ?? []
        TodaySection(title: "Recent notes") {
            if recent.isEmpty {
                TodayEmptyLine(text: "The last five sessions you took notes in show here.")
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(recent) { session in
                        Button {
                            model.openSession(id: session.id)
                        } label: {
                            HStack(alignment: .firstTextBaseline, spacing: scale(10)) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(session.title)
                                        .sbType(SBType.rowEmphasis)
                                        .foregroundStyle(SBColor.textPrimary)
                                        .lineLimit(1)
                                    if let line = session.firstNoteLine {
                                        Text(line)
                                            .sbFont(12)
                                            .foregroundStyle(SBColor.textSecondary)
                                            .lineLimit(1)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                Text(
                                    RelativeDate.string(for: session.sync.updatedAt, relativeTo: model.now())
                                )
                                .sbFont(12)
                                .foregroundStyle(SBColor.textTertiary)
                                .lineLimit(1)
                            }
                            .padding(.vertical, scale(7))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens the session")
                    }
                }
            }
        }
    }
}

// MARK: This term at a glance

/// Four numbers, no charts.
struct GlanceSection: View {
    @Environment(\.sbScale) private var scale
    let glance: TermGlance
    let termTitle: String

    var body: some View {
        TodaySection(title: "This term at a glance", note: termTitle) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(glance.lines.enumerated()), id: \.offset) { _, line in
                    HStack(alignment: .firstTextBaseline) {
                        Text(line.label)
                            .sbType(SBType.row)
                            .foregroundStyle(SBColor.textSecondary)
                        Spacer(minLength: scale(12))
                        Text(line.value)
                            .sbType(SBType.row)
                            .foregroundStyle(SBColor.textPrimary)
                            .monospacedDigit()
                    }
                    .padding(.vertical, scale(6))
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

// MARK: Term strip (§9 "Signature details")

/// Full width beneath the columns, with its heading and the room it needs; hovering a mark
/// says what it is.
struct TermStripSection: View {
    let strip: TermStrip

    var body: some View {
        TodaySection(title: strip.title, note: strip.caption) {
            TermStripView(strip)
        }
    }
}
