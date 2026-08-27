import SwiftUI
import UIKit

struct StreakCalendarView: View {
    @Environment(AppSession.self) private var session
    @State private var month = Date()

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 1
        cal.locale = Locale(identifier: "en_US_POSIX")
        return cal
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                monthHeader
                weekdayHeader
                dayGrid
                stats
                EmberButton(title: "Share your streak") {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    share()
                }
                legend
            }
            .fueg0ScreenPadding()
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.xxl)
        }
        .background(Palette.background.ignoresSafeArea())
        .navigationTitle(monthTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    share()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share streak")
            }
        }
        .preferredColorScheme(.dark)
    }

    private var monthTitle: String {
        month.formatted(.dateTime.month(.wide).year())
    }

    private var monthHeader: some View {
        HStack {
            Button {
                month = calendar.date(byAdding: .month, value: -1, to: month) ?? month
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Palette.ember)
                    .frame(width: 44, height: 44)
            }
            Spacer()
            Text(monthTitle)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.textPrimary)
            Spacer()
            Button {
                month = calendar.date(byAdding: .month, value: 1, to: month) ?? month
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Palette.ember)
                    .frame(width: 44, height: 44)
            }
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(Array(["S", "M", "T", "W", "T", "F", "S"].enumerated()), id: \.offset) { _, day in
                Text(day)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.ember)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var dayGrid: some View {
        let cells = monthCells
        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7),
            spacing: 6
        ) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                dayCell(cell)
            }
        }
    }

    private func dayCell(_ cell: DayCell) -> some View {
        Group {
            if let day = cell.day {
                let completed = session.burnedDays.contains(cell.key)
                Text("\(day)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(completed ? Palette.onEmber : Palette.textMuted)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(
                        RoundedRectangle(cornerRadius: Spacing.radiusSm, style: .continuous)
                            .fill(completed ? Palette.ember.opacity(0.92) : Palette.surfaceElevated)
                    )
                    .overlay {
                        if cell.isToday {
                            RoundedRectangle(cornerRadius: Spacing.radiusSm, style: .continuous)
                                .stroke(Palette.ember, lineWidth: 2)
                        }
                    }
                    .accessibilityLabel(accessibility(day: day, completed: completed, today: cell.isToday))
            } else {
                Color.clear.frame(minHeight: 40)
            }
        }
    }

    private var stats: some View {
        HStack(spacing: 0) {
            VStack(spacing: 4) {
                Text("\(session.streakDays)")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Palette.textPrimary)
                Text("DAY STREAK")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(Palette.textMuted)
            }
            .frame(maxWidth: .infinity)
            VStack(spacing: 4) {
                Text("\(session.burnedDays.count)")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Palette.textPrimary)
                Text("TOTAL FORGED")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(Palette.textMuted)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Spacing.radiusMd, style: .continuous)
                .fill(Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.radiusMd, style: .continuous)
                .stroke(Palette.emberBorder, lineWidth: 1)
        )
    }

    private var legend: some View {
        HStack(spacing: Spacing.md) {
            legendItem(color: Palette.ember.opacity(0.92), label: "Completed")
            legendItem(color: Palette.surfaceElevated, label: "Missed")
            legendItem(color: Palette.background, label: "Today", border: Palette.ember)
        }
        .frame(maxWidth: .infinity)
    }

    private func legendItem(color: Color, label: String, border: Color? = nil) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(color)
                .frame(width: 14, height: 14)
                .overlay {
                    if let border {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(border, lineWidth: 2)
                    }
                }
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(Palette.textMuted)
        }
    }

    private var monthCells: [DayCell] {
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) ?? month
        let days = calendar.range(of: .day, in: .month, for: start)?.count ?? 30
        let weekday = calendar.component(.weekday, from: start)
        let leading = weekday - calendar.firstWeekday
        let today = dayStamp(Date())
        var cells: [DayCell] = (0..<leading).map { _ in DayCell(day: nil, key: "", isToday: false) }
        for day in 1...days {
            let date = calendar.date(byAdding: .day, value: day - 1, to: start) ?? start
            let key = dayStamp(date)
            cells.append(DayCell(day: day, key: key, isToday: key == today))
        }
        return cells
    }

    private func dayStamp(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private func accessibility(day: Int, completed: Bool, today: Bool) -> String {
        var parts = ["Day \(day)"]
        if today { parts.append("today") }
        parts.append(completed ? "completed" : "missed")
        return parts.joined(separator: ", ")
    }

    private func share() {
        let name = session.displayName
        let text = """
        🔥 \(name) is on a \(session.streakDays)-day IGNITE streak on Fueg0!
        \(session.burnedDays.count) total days forged in fire.
        No excuses. Only fire. 💪
        #Fueg0 #NoExcusesOnlyFire
        """
        guard let presenter = PresentingViewController.top() else { return }
        let share = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let pop = share.popoverPresentationController {
            pop.sourceView = presenter.view
            pop.sourceRect = CGRect(x: presenter.view.bounds.midX, y: 80, width: 1, height: 1)
        }
        presenter.present(share, animated: true)
    }
}

private struct DayCell {
    var day: Int?
    var key: String
    var isToday: Bool
}
