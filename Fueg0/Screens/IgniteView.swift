import SwiftUI

struct IgniteView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var showingBurn = true
    @State private var result: IgniteResult?
    @State private var completing = false
    @State private var feed: [DailyVideo] = []
    @State private var feedIndex = 0
    @State private var fireNotice: String?
    @State private var fireLoading = true
    @State private var fireUnavailable = false
    @State private var softPlaybackFailures = 0
    @State private var loadGeneration = 0

    private var wod: (title: String, detail: String) {
        SampleContent.todaysWOD()
    }

    private var currentFire: DailyVideo? {
        feed.indices.contains(feedIndex) ? feed[feedIndex] : nil
    }

    private var fireQuote: String {
        if let quote = currentFire?.quote, !quote.isEmpty { return quote }
        return SampleContent.quote()
    }

    private var fireFailureMessage: String {
        if feed.isEmpty {
            return "No motivational videos loaded."
        }
        return "Can't play YouTube right now."
    }

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            if showingBurn {
                burnStage
            } else {
                ritual
                    .transition(.opacity)
            }
        }
        .onAppear {
            Task { await loadFire() }
        }
    }

    private var burnStage: some View {
        HellFireCanvas {
            withAnimation(.easeInOut(duration: 0.35)) {
                showingBurn = false
            }
        }
    }

    private var ritual: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    DailyFirePlayer(
                        video: currentFire,
                        failed: fireUnavailable,
                        loading: fireLoading,
                        failureMessage: fireFailureMessage,
                        onRetry: { Task { await loadFire(force: true) } },
                        onPlaying: { id in notePlaying(id) },
                        onUnplayable: { id, code in noteUnplayable(id: id, code: code) }
                    )

                    if let title = currentFire?.title, !title.isEmpty, !fireUnavailable, !fireLoading {
                        Text(title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Palette.textPrimary)
                    }

                    if let fireNotice, !fireNotice.isEmpty {
                        Text(fireNotice)
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text("Today’s fire")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.ember)

                    Text("“\(fireQuote)”")
                        .font(.system(size: 22, weight: .regular).italic())
                        .foregroundStyle(Palette.textPrimary)
                        .lineSpacing(4)

                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("TODAY’S WOD")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Palette.ember)
                            Text(wod.title)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(Palette.textPrimary)
                            Text(wod.detail)
                                .font(.system(size: 15))
                                .foregroundStyle(Palette.textSecondary)
                                .lineSpacing(4)
                        }
                    }

                    streakLock

                    if let result, !result.alreadyComplete {
                        Text("+\(result.xpAwarded) XP · \(result.newStreak)-day streak")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Palette.gold)
                            .frame(maxWidth: .infinity)
                    }

                    EmberButton(
                        title: primaryTitle,
                        enabled: !completing,
                        loading: completing
                    ) {
                        Task { await complete() }
                    }
                }
                .fueg0ScreenPadding()
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.xxl)
            }
            .background(Palette.background.ignoresSafeArea())
            .navigationTitle("Ignite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Palette.textSecondary)
                }
            }
        }
    }

    private var primaryTitle: String {
        if session.ignitedToday || result != nil {
            return "Return home"
        }
        return "Lock the chain"
    }

    private var streakLock: some View {
        SurfaceCard {
            HStack(spacing: 12) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Palette.ember)
                Text("\(session.streakDays)")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Palette.ember)
                Text(chainLabel)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
                Image(systemName: session.ignitedToday ? "checkmark.circle.fill" : "lock")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Palette.ember)
            }
        }
    }

    private var chainLabel: String {
        if session.ignitedToday { return "CHAIN SECURE" }
        if session.streakDays == 0 { return "START THE CHAIN" }
        return "LOCK STREAK"
    }

    private func loadFire(force: Bool = false) async {
        loadGeneration += 1
        let generation = loadGeneration
        fireLoading = true
        fireUnavailable = false
        softPlaybackFailures = 0
        feedIndex = 0
        let loaded = await DailyFireService.loadFeed(forceRefresh: force)
        guard generation == loadGeneration else { return }
        feed = loaded.videos
        fireNotice = loaded.notice
        fireLoading = false
        fireUnavailable = loaded.videos.isEmpty
    }

    private func notePlaying(_ id: String) {
        guard currentFire?.videoId == id else { return }
        softPlaybackFailures = 0
        DailyFireService.rememberPlayed(id)
    }

    private func noteUnplayable(id: String, code: String) {
        guard currentFire?.videoId == id, !fireUnavailable else { return }
        if YouTubePlaybackFailure.videoFaultCodes.contains(code) {
            DailyFireService.block(id)
        } else {
            softPlaybackFailures += 1
            if softPlaybackFailures >= 2 {
                fireUnavailable = true
                return
            }
        }
        if feedIndex + 1 < feed.count {
            feedIndex += 1
        } else {
            fireUnavailable = true
        }
    }

    private func complete() async {
        if session.ignitedToday || result != nil {
            dismiss()
            return
        }
        completing = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let awarded = session.completeIgnite()
        result = awarded
        completing = false
        try? await Task.sleep(for: .milliseconds(900))
        dismiss()
    }
}
