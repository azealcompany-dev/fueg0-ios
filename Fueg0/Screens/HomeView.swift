import SwiftUI

struct HomeView: View {
    @Environment(AppSession.self) private var session

    private var tomorrow: String {
        let date = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        return date.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    var body: some View {
        @Bindable var session = session

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    header
                    quote
                    EmberButton(title: session.ignitedToday ? "Reignite" : "Ignite") {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        session.ignite()
                    }
                    missions
                }
                .fueg0ScreenPadding()
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.xxl)
            }
            .background(Palette.background.ignoresSafeArea())
            .navigationBarHidden(true)
            .sheet(isPresented: $session.showIgnite) {
                IgniteView()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(Palette.background)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Fueg0")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.textMuted)

            Text("Ready, \(session.displayName).")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Palette.textPrimary)

            HStack(spacing: 8) {
                QuietPill(label: "\(session.streakDays)-day streak")
                QuietPill(label: "\(session.xp.formatted()) XP", accent: true)
                QuietPill(label: session.rank, accent: true)
            }
        }
    }

    private var quote: some View {
        Text("“\(SampleContent.quote())”")
            .font(.system(size: 17, weight: .regular).italic())
            .foregroundStyle(Palette.textSecondary)
            .lineSpacing(5)
    }

    private var missions: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Tomorrow’s missions")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Palette.textPrimary)
                    Spacer()
                    Text("\(session.completedMissionIDs.count)/\(SampleContent.missions.count)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Palette.textSecondary)
                }

                Text(tomorrow)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.textMuted)

                VStack(spacing: 8) {
                    ForEach(SampleContent.missions) { mission in
                        MissionRow(
                            mission: mission,
                            done: session.completedMissionIDs.contains(mission.id)
                        ) {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            session.toggleMission(mission.id)
                        }
                    }
                }
            }
        }
    }
}

private struct MissionRow: View {
    let mission: Mission
    let done: Bool
    var onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(done ? Palette.ember : Palette.textMuted)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 2) {
                    Text(mission.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.textPrimary)
                    Text(mission.detail)
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.textMuted)
                }

                Spacer(minLength: 8)

                Text("+\(mission.xp)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.gold)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(done ? Palette.ember.opacity(0.06) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(done ? Palette.emberBorder : Palette.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
