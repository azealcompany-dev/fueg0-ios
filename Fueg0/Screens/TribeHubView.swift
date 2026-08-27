import SwiftUI

struct TribeHubView: View {
    @Environment(AppSession.self) private var session

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                if let tribe = session.tribe {
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

                    Text("“\(tribe.warCry)”")
                        .font(.system(size: 16).italic())
                        .foregroundStyle(Palette.textSecondary)
                        .lineSpacing(4)

                    Text(tribe.traits)
                        .font(.system(size: 15))
                        .foregroundStyle(Palette.textSecondary)
                } else {
                    Text("No tribe claimed yet")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Palette.textPrimary)
                    Text("Replay onboarding from Settings to pick a pack.")
                        .font(.system(size: 15))
                        .foregroundStyle(Palette.textSecondary)
                }

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Coming in this native port")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Palette.textPrimary)
                        Text("War room, weekly leaderboard, feed, and war cry live in the Flutter app until the next native milestone.")
                            .font(.system(size: 14))
                            .foregroundStyle(Palette.textMuted)
                            .lineSpacing(3)
                    }
                }
            }
            .fueg0ScreenPadding()
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.xxl)
        }
        .background(Palette.background.ignoresSafeArea())
        .navigationTitle("Tribe")
        .navigationBarTitleDisplayMode(.inline)
    }
}
