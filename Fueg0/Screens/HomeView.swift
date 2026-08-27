import SwiftUI

struct HomeView: View {
    @Environment(AppSession.self) private var session
    var onOpenSettings: () -> Void = {}

    @State private var showIgnite = false

    private var tomorrow: String {
        let date = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        return date.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    private var homeTitle: String {
        let name = session.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty || name == "Warrior" { return "Home" }
        return name
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Ready.")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Palette.textMuted)
                        Text("“\(SampleContent.quote())”")
                            .font(.system(size: 20, weight: .regular).italic())
                            .foregroundStyle(Palette.textPrimary)
                            .lineSpacing(4)

                        HStack(spacing: 8) {
                            QuietPill(label: "\(session.streakDays)-day streak")
                            QuietPill(label: "\(session.xp.formatted()) XP", accent: true)
                            QuietPill(label: session.rank, accent: true)
                        }
                        .padding(.top, 4)
                    }
                    .padding(.vertical, 6)
                }
                .fueg0RowSurface()

                Section {
                    EmberButton(title: session.ignitedToday ? "Reignite" : "Ignite") {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showIgnite = true
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
                .fueg0RowSurface(Color.clear)
                .listRowSeparator(.hidden)

                Section {
                    ForEach(SampleContent.missions) { mission in
                        MissionRow(
                            mission: mission,
                            done: session.completedMissionIDs.contains(mission.id)
                        ) {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            session.toggleMission(mission.id)
                        }
                        .fueg0RowSurface(session.completedMissionIDs.contains(mission.id) ? Palette.ember.opacity(0.08) : Palette.surface)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button {
                                session.toggleMission(mission.id)
                            } label: {
                                Label(
                                    session.completedMissionIDs.contains(mission.id) ? "Undo" : "Done",
                                    systemImage: session.completedMissionIDs.contains(mission.id) ? "arrow.uturn.backward" : "checkmark"
                                )
                            }
                            .tint(Palette.ember)
                        }
                    }
                } header: {
                    HStack {
                        Text("Tomorrow’s missions")
                        Spacer()
                        Text("\(session.completedMissionIDs.count)/\(SampleContent.missions.count)")
                            .foregroundStyle(Palette.textMuted)
                    }
                } footer: {
                    Text(tomorrow)
                }
            }
            .fueg0ListChrome()
            .navigationTitle(homeTitle)
            .navigationBarTitleDisplayMode(.large)
            .fueg0NavigationPrompt("Fueg0")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onOpenSettings) {
                        Image(systemName: "person.crop.circle")
                    }
                    .accessibilityLabel("Profile and settings")
                }
            }
            .sheet(isPresented: $showIgnite) {
                IgniteView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(28)
                    .preferredColorScheme(.dark)
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
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(done ? Palette.ember : Palette.textMuted)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 2) {
                    Text(mission.title)
                        .font(.system(size: 16, weight: .semibold))
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
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mission.title)
        .accessibilityValue(done ? "Complete" : "Not complete")
    }
}
