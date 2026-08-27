import SwiftUI

struct IgniteView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var showingBurn = true
    @State private var burnOpacity = 0.0
    @State private var result: IgniteResult?
    @State private var completing = false

    private var wod: (title: String, detail: String) {
        SampleContent.todaysWOD()
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
        .onAppear { playBurn() }
    }

    private var burnStage: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            Text("BURN")
                .font(.system(size: 56, weight: .heavy))
                .tracking(10)
                .foregroundStyle(Palette.gold)
                .opacity(burnOpacity)
        }
    }

    private var ritual: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    Text("Today’s fire")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.ember)

                    Text("“\(SampleContent.quote())”")
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

    private func playBurn() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        withAnimation(.easeOut(duration: 0.45)) {
            burnOpacity = 1
        }
        Task {
            try? await Task.sleep(for: .milliseconds(1_100))
            withAnimation(.easeInOut(duration: 0.35)) {
                showingBurn = false
            }
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
