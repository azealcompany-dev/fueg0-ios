import SwiftUI

struct TribeHubView: View {
    @Environment(AppSession.self) private var session
    @State private var model = TribeHubModel()
    @State private var showSelection = false

    var body: some View {
        List {
            if session.tribe == nil {
                Section {
                    Fueg0EmptyState(
                        symbol: "person.3",
                        title: "No tribe claimed yet",
                        copy: "Seven tribes. One fire. Pick a pack to earn points together — and to see the war-room feed."
                    )
                    .fueg0RowSurface()
                    Button("Choose a tribe") {
                        showSelection = true
                    }
                    .foregroundStyle(Palette.ember)
                    .fueg0RowSurface()
                }
            } else if let tribe = session.tribe {
                Section {
                    membershipHeader(tribe)
                        .fueg0RowSurface()
                    statusCard(tribe)
                        .fueg0RowSurface()
                }
            }

            if let message = session.tribeSyncError {
                Section {
                    Fueg0ErrorState(message: message, retryTitle: "Sync again") {
                        Task { await retryMembershipSync() }
                    }
                    .fueg0RowSurface()
                }
            }

            leaderboardSection
            if session.tribe != nil {
                feedSection
            }
        }
        .fueg0ListChrome()
        .navigationTitle("Tribe")
        .navigationBarTitleDisplayMode(.large)
        .refreshable { await reload() }
        .task { await reload() }
        .onChange(of: session.tribe?.id) { _, _ in
            Task { await reload() }
        }
        .sheet(isPresented: $showSelection) {
            NavigationStack {
                TribeSelectionView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showSelection = false }
                        }
                    }
            }
            .presentationDetents([.large])
            .preferredColorScheme(.dark)
        }
    }

    private func membershipHeader(_ tribe: Tribe) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: 12) {
                Image(systemName: tribe.symbol)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Palette.ember)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Palette.surfaceElevated))
                    .overlay(Circle().stroke(Palette.hairline, lineWidth: 1))

                VStack(alignment: .leading, spacing: 2) {
                    Text(tribe.name)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Palette.textPrimary)
                    Text(tribe.motto)
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.textMuted)
                }
            }

            Text("“\(tribe.dailyWarCry())”")
                .font(.system(size: 16).italic())
                .foregroundStyle(Palette.textSecondary)
                .lineSpacing(4)
        }
        .padding(.vertical, 4)
    }

    private func statusCard(_ tribe: Tribe) -> some View {
        let mine = model.entries.first(where: { $0.isUserTribe })
        let total = mine?.totalPoints ?? 0
        let weekly = mine?.weeklyPoints ?? 0
        let level = mine?.level ?? Tribe.level(fromTotalPoints: total)
        let bonus = Tribe.xpBonusPercent(forLevel: level)
        let remaining = Tribe.pointsToNextLevel(total)

        return VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                statusStat(label: "Tribe lvl", value: "\(level)")
                Spacer()
                statusStat(label: "This week", value: "\(weekly)")
                Spacer()
                statusStat(label: "Your pts", value: "\(session.tribeContributions)")
                Spacer()
                statusStat(label: "XP bonus", value: "+\(bonus)%")
            }

            GeometryReader { geo in
                let span = max(level * 500, 1)
                let done = min(1, CGFloat(span - remaining) / CGFloat(span))
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.surfaceElevated)
                    Capsule()
                        .fill(Palette.ember)
                        .frame(width: max(4, geo.size.width * done))
                }
            }
            .frame(height: 4)

            Text("\(max(0, remaining)) pts to the next tribe level")
                .font(.system(size: 12))
                .foregroundStyle(Palette.textMuted)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(tribe.name) level \(level)")
    }

    private func statusStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Palette.textMuted)
            Text(value)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Palette.textPrimary)
        }
    }

    @ViewBuilder
    private var leaderboardSection: some View {
        Section {
            if model.isLoading && model.entries.isEmpty {
                HStack(spacing: 10) {
                    ProgressView().tint(Palette.ember)
                    Text("Loading tribes…")
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.textMuted)
                }
                .fueg0RowSurface()
            } else if let error = model.leaderboardError, model.entries.isEmpty {
                Fueg0ErrorState(message: error) {
                    Task { await reload() }
                }
                .fueg0RowSurface()
            } else if model.entries.isEmpty {
                Fueg0EmptyState(
                    symbol: "flag",
                    title: "No scores yet",
                    copy: "The seven tribes will show here as soon as points land."
                )
                .fueg0RowSurface()
            } else {
                ForEach(model.entries) { entry in
                    LeaderboardRow(entry: entry)
                        .fueg0RowSurface(entry.isUserTribe ? Palette.ember.opacity(0.08) : Palette.surface)
                }
            }
        } header: {
            HStack {
                Text("Weekly leaderboard")
                Spacer()
                Text("Resets Monday")
                    .foregroundStyle(Palette.textMuted)
            }
        }
    }

    @ViewBuilder
    private var feedSection: some View {
        Section {
            switch model.feedState {
            case .loading:
                HStack(spacing: 10) {
                    ProgressView().tint(Palette.ember)
                    Text("Loading feed…")
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.textMuted)
                }
                .fueg0RowSurface()
            case .unavailable, .empty:
                Fueg0EmptyState(
                    symbol: "flame",
                    title: "No activity yet",
                    copy: "When someone joins or finishes a goal, it shows up here."
                )
                .fueg0RowSurface()
            case .loaded(let items):
                ForEach(Array(items.prefix(10))) { activity in
                    FeedRow(activity: activity)
                        .fueg0RowSurface()
                }
            }
        } header: {
            Text("Tribe feed")
        }
    }

    private func reload() async {
        await model.load(userTribeID: session.tribe?.id)
    }

    private func retryMembershipSync() async {
        guard let tribe = session.tribe else { return }
        _ = await session.joinTribe(tribe)
        await reload()
    }
}

@MainActor
@Observable
final class TribeHubModel {
    enum FeedState: Equatable {
        case loading
        case loaded([TribeActivity])
        case empty
        case unavailable
    }

    var isLoading = false
    var leaderboardError: String?
    var entries: [TribeLeaderboardEntry] = []
    var feedState: FeedState = .empty

    private let service = TribeService()

    func load(userTribeID: String?) async {
        isLoading = entries.isEmpty
        if userTribeID != nil, case .loaded = feedState {
            // keep last feed while refreshing
        } else if userTribeID != nil {
            feedState = .loading
        } else {
            feedState = .empty
        }

        do {
            entries = try await service.fetchLeaderboard(userTribeID: userTribeID)
            leaderboardError = nil
        } catch {
            if entries.isEmpty {
                leaderboardError = "Could not load the tribe leaderboard."
            }
        }

        if let userTribeID {
            switch await service.fetchFeed(tribeID: userTribeID) {
            case .loaded(let items):
                feedState = items.isEmpty ? .empty : .loaded(items)
            case .unavailable:
                feedState = .unavailable
            }
        } else {
            feedState = .empty
        }

        isLoading = false
    }
}

private struct LeaderboardRow: View {
    let entry: TribeLeaderboardEntry

    var body: some View {
        HStack(spacing: 12) {
            Text("#\(entry.rank)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(entry.rank <= 3 ? Palette.ember : Palette.textMuted)
                .frame(width: 28, alignment: .leading)

            Image(systemName: entry.tribe.symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(entry.isUserTribe ? Palette.ember : Palette.textSecondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.tribe.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(entry.isUserTribe ? Palette.textPrimary : Palette.textPrimary)
                    if entry.isUserTribe {
                        Text("Yours")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Palette.ember)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .overlay(
                                Capsule().stroke(Palette.emberBorder, lineWidth: 1)
                            )
                    }
                }
                Text("Lvl \(entry.level)")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.textMuted)
            }

            Spacer(minLength: 8)

            Text("\(entry.weeklyPoints)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Palette.textPrimary)
            Text("pts")
                .font(.system(size: 11))
                .foregroundStyle(Palette.textMuted)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.tribe.name), rank \(entry.rank), \(entry.weeklyPoints) weekly points")
    }
}

private struct FeedRow: View {
    let activity: TribeActivity

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(initial)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.ember)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Palette.surfaceElevated))
                .overlay(Circle().stroke(Palette.hairline, lineWidth: 1))

            VStack(alignment: .leading, spacing: 4) {
                (Text(activity.userName).fontWeight(.semibold).foregroundColor(Palette.textPrimary)
                 + Text(" \(activity.message)").foregroundColor(Palette.textSecondary))
                    .font(.system(size: 14))
                Text(activity.timeAgo)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.textMuted)
            }
        }
        .padding(.vertical, 4)
    }

    private var initial: String {
        let trimmed = activity.userName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.first.map { String($0).uppercased() } ?? "?"
    }
}
