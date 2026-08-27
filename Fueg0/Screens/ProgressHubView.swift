import SwiftUI

struct ProgressHubView: View {
    @Environment(AppSession.self) private var session
    @Environment(StoreService.self) private var store
    @State private var model = DailyLawsModel()
    @State private var showPaywall = false

    var body: some View {
        Group {
            if model.loading && model.laws.isEmpty {
                loadingState
            } else if let error = model.loadError, model.laws.isEmpty {
                List {
                    Section {
                        Fueg0ErrorState(message: error) {
                            Task { await model.load(ignitedToday: session.ignitedToday) }
                        }
                        .fueg0RowSurface()
                    }
                }
                .fueg0ListChrome()
            } else if model.laws.isEmpty {
                emptyState
            } else {
                lawsList
            }
        }
        .navigationTitle("Progress")
        .navigationBarTitleDisplayMode(.large)
        .fueg0NavigationPrompt("Daily Laws")
        .task { await model.load(ignitedToday: session.ignitedToday) }
        .onChange(of: session.ignitedToday) { _, ignited in
            model.syncIgniteLaws(ignitedToday: ignited)
        }
        .fueg0PaywallSheet($showPaywall)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !model.checkable.isEmpty {
                    Text("\(model.completedCount)/\(model.checkable.count)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.ember)
                        .accessibilityLabel("\(model.completedCount) of \(model.checkable.count) laws complete")
                }
            }
        }
    }

    private var loadingState: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    ProgressView().tint(Palette.ember)
                    Text("Reading today’s laws…")
                        .font(.system(size: 15))
                        .foregroundStyle(Palette.textMuted)
                }
                .fueg0RowSurface()
            }
        }
        .fueg0ListChrome()
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No daily laws", systemImage: "checklist")
        } description: {
            Text("Your laws will land here. Pull to retry, or come back after the fire is set.")
        }
        .tint(Palette.ember)
        .foregroundStyle(Palette.textPrimary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background.ignoresSafeArea())
    }

    private var lawsList: some View {
        List {
            Section {
                progressExtras
                    .fueg0RowSurface()
            } header: {
                Text("Predictive Progress")
            }

            Section {
                overviewCard
                    .fueg0RowSurface()
            }

            Section {
                ForEach(model.checkable) { goal in
                    LawRow(
                        goal: goal,
                        done: model.completions[goal.id] == true,
                        stats: model.stats[goal.id]
                    ) {
                        Task { await toggle(goal) }
                    }
                    .fueg0RowSurface(model.completions[goal.id] == true ? Palette.ember.opacity(0.08) : Palette.surface)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button {
                            Task { await toggle(goal) }
                        } label: {
                            Label(
                                model.completions[goal.id] == true ? "Undo" : "Forge",
                                systemImage: model.completions[goal.id] == true ? "arrow.uturn.backward" : "checkmark"
                            )
                        }
                        .tint(Palette.ember)
                    }
                }
            } header: {
                HStack {
                    Text("Daily Laws")
                    Spacer()
                    Text(statusLabel)
                        .foregroundStyle(Palette.ember)
                }
            } footer: {
                Text("Check each law as you forge it. Completions save on this iPhone with the same keys as Flutter.")
            }

            if let lock = model.lockLaw {
                Section {
                    LockRow(goal: lock, sealed: model.allComplete || session.ignitedToday)
                        .fueg0RowSurface()
                }
            }
        }
        .fueg0ListChrome()
        .refreshable { await model.load(ignitedToday: session.ignitedToday) }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                EmberButton(
                    title: lockTitle,
                    enabled: model.allComplete && !session.ignitedToday,
                    loading: model.locking
                ) {
                    Task { await lockStreak() }
                }
                .padding(.horizontal, Spacing.screen)
                .padding(.vertical, Spacing.md)
            }
            .background(.ultraThinMaterial)
        }
    }

    @ViewBuilder
    private var progressExtras: some View {
        if store.isLoading && !store.isPremium {
            HStack(spacing: 12) {
                ProgressView().tint(Palette.ember)
                Text("Checking premium…")
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.textMuted)
            }
            .padding(.vertical, 8)
        } else if store.isPremium {
            PredictiveProgressExtras(overview: model.overview)
        } else {
            PremiumGateCard(featureName: "Predictive Progress") {
                showPaywall = true
            }
        }
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(chainHeadline)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.ember)

            Text("DAY \(max(session.streakDays, 1))")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Palette.textPrimary)

            Text(chainUrgency)
                .font(.system(size: 14))
                .foregroundStyle(Palette.textSecondary)

            if let overview = model.overview {
                HStack(spacing: 8) {
                    statTile("Today", "\(overview.todayCompleted)/\(overview.todayTotal)", "\(overview.todayPercent)% forged")
                    statTile("Week", "\(overview.weeklyPercent)%", "weekly rate")
                    statTile("Streak", "\(overview.perfectDayStreak)", overview.perfectDayStreak == 1 ? "perfect day" : "perfect days")
                }
            }

            ProgressView(value: model.checkable.isEmpty ? 0 : Double(model.completedCount) / Double(model.checkable.count))
                .tint(model.allComplete ? Palette.emberDeep : Palette.ember)
        }
        .padding(.vertical, 6)
    }

    private func statTile(_ label: String, _ value: String, _ subtitle: String) -> some View {
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

    private var statusLabel: String {
        if session.ignitedToday { return "SEALED" }
        if model.allComplete { return "FORGED" }
        return "IN PROGRESS"
    }

    private var lockTitle: String {
        if session.ignitedToday { return "Streak already locked today" }
        if model.allComplete { return model.lockLaw?.title ?? "Lock streak" }
        return "Complete all \(model.checkable.count) laws first"
    }

    private var chainHeadline: String {
        if session.ignitedToday { return "CHAIN SECURE" }
        if session.streakDays == 0 { return "START THE CHAIN" }
        return "HOLD THE CHAIN"
    }

    private var chainUrgency: String {
        if session.ignitedToday { return "Today is sealed. Come back at sunrise." }
        if session.streakDays == 0 { return "Forge every law, then lock the day." }
        return "Miss a day and the chain breaks."
    }

    private func toggle(_ goal: DailyGoal) async {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        await model.toggle(goal, session: session)
        if model.allComplete {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
    }

    private func lockStreak() async {
        guard model.allComplete, !session.ignitedToday else { return }
        model.locking = true
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        _ = session.completeIgnite()
        model.locking = false
    }
}

@MainActor
@Observable
final class DailyLawsModel {
    var laws: [DailyGoal] = []
    var completions: [String: Bool] = [:]
    var stats: [String: GoalCompletionStats] = [:]
    var overview: ProgressOverview?
    var loading = true
    var locking = false
    var loadError: String?

    private let service = GoalsService()
    private let tribe = TribeService()

    var checkable: [DailyGoal] { service.checkableGoals(laws) }
    var lockLaw: DailyGoal? { laws.count > 1 ? laws.last : nil }
    var completedCount: Int { checkable.filter { completions[$0.id] == true }.count }
    var allComplete: Bool { !checkable.isEmpty && checkable.allSatisfy { completions[$0.id] == true } }

    func load(ignitedToday: Bool) async {
        loading = laws.isEmpty
        loadError = nil
        let loaded = service.loadGoals()
        laws = loaded.isEmpty ? GoalsService.defaultGoals : loaded
        completions = service.completions(for: service.todayKey(), goals: laws)
        if ignitedToday {
            markIgniteLaws()
        }
        stats = service.stats(goals: laws)
        overview = service.overview(goals: laws)
        loading = false
        if laws.isEmpty {
            loadError = "Daily laws didn’t load. Try again."
        }
    }

    func syncIgniteLaws(ignitedToday: Bool) {
        guard ignitedToday else { return }
        markIgniteLaws()
        stats = service.stats(goals: laws)
        overview = service.overview(goals: laws)
    }

    func toggle(_ goal: DailyGoal, session: AppSession) async {
        let next = !(completions[goal.id] ?? false)
        completions = service.setCompletion(goalId: goal.id, completed: next, goals: laws)
        stats = service.stats(goals: laws)
        overview = service.overview(goals: laws)

        guard let tribeID = session.tribe?.id, let uid = session.userUID else { return }
        let delta: Int
        if next {
            delta = await tribe.awardPointsForGoal(
                goalId: goal.id,
                goalTitle: goal.title,
                tribeID: tribeID,
                userName: session.displayName,
                userID: uid
            )
        } else {
            delta = await tribe.removePointsForGoal(goalId: goal.id, tribeID: tribeID, userID: uid)
        }
        if delta != 0 {
            session.applyTribeContributionDelta(delta)
        }
    }

    private func markIgniteLaws() {
        var changed = false
        for id in ["default_ignite", "default_wod"] where laws.contains(where: { $0.id == id }) {
            if completions[id] != true {
                completions[id] = true
                changed = true
            }
        }
        if changed {
            service.saveCompletions(completions, date: service.todayKey())
        }
    }
}

private struct LawRow: View {
    let goal: DailyGoal
    let done: Bool
    let stats: GoalCompletionStats?
    var onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(done ? Palette.ember : Palette.textMuted)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 6) {
                    Text(goal.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Palette.textPrimary)
                    Text(goal.description)
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                    if let stats {
                        HStack(spacing: 12) {
                            miniStat("Week", "\(stats.weekCompletions)/\(stats.weekDaysElapsed) · \(stats.weekPercent)%")
                            miniStat("Month", "\(stats.monthCompletions)/\(stats.monthDaysElapsed) · \(stats.monthPercent)%")
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(goal.title)
        .accessibilityValue(done ? "Complete" : "Not complete")
    }

    private func miniStat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Palette.textMuted)
            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Palette.ember)
        }
    }
}

private struct LockRow: View {
    let goal: DailyGoal
    let sealed: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: sealed ? "lock.fill" : "lock")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Palette.ember)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(goal.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
                Text(goal.description)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.textMuted)
                Text("Seal the day once all laws are forged")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.ember)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
