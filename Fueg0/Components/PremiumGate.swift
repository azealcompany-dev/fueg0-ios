import SwiftUI

struct PremiumGateCard: View {
    let featureName: String
    var onUnlock: () -> Void

    var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "lock.fill")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Palette.ember)

            Text("PREMIUM FEATURE")
                .font(.system(size: 13, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(Palette.ember)

            Text("\(featureName) requires Fueg0 Premium.\nStart your 7-day free trial.")
                .font(.system(size: 14))
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            EmberButton(title: "Unlock Premium", action: onUnlock)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

struct PredictiveProgressExtras: View {
    let overview: ProgressOverview?
    var report: WarriorProgressReport?
    var onEditStats: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("PREDICTIVE PROGRESS")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.ember)

            if let overview {
                HStack(spacing: 8) {
                    extraTile("Week", "\(overview.weeklyPercent)%", "forge rate")
                    extraTile(
                        "Streak",
                        "\(overview.perfectDayStreak)",
                        overview.perfectDayStreak == 1 ? "perfect day" : "perfect days"
                    )
                    extraTile("Today", "\(overview.todayPercent)%", "laws forged")
                }
            }

            if let report {
                Text(report.prediction.headlineMessage)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    extraTile("TDEE", "\(Int(report.prediction.effectiveTdee.rounded()))", "kcal")
                    extraTile("Progress", "\(Int(report.prediction.progressPercent.rounded()))%", "to target")
                    extraTile("Score", "\(report.consistencyScore)", trendLabel(report.trend))
                }
                ForEach(report.prediction.improvementTips.prefix(3), id: \.self) { tip in
                    Text(tip)
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button("Edit warrior stats", action: onEditStats)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.ember)
            } else {
                Text(tip)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Enter warrior stats", action: onEditStats)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.ember)
            }
        }
        .padding(.vertical, 6)
    }

    private func trendLabel(_ trend: ProgressTrend) -> String {
        switch trend {
        case .improving: return "improving"
        case .stagnant: return "holding"
        case .declining: return "slipping"
        }
    }

    private var tip: String {
        guard let overview else {
            return "Forge today’s laws to start a consistency score."
        }
        if overview.weeklyPercent >= 80 {
            return "Hold the chain. Your weekly rate is already in striking range."
        }
        if overview.weeklyPercent >= 40 {
            return "Lift one more law each day and the weekly trend turns."
        }
        return "Start with a single law. Consistency is the target, not volume."
    }

    private func extraTile(_ label: String, _ value: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Palette.textMuted)
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Palette.textPrimary)
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(Palette.textMuted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Palette.surfaceElevated)
        )
    }
}
