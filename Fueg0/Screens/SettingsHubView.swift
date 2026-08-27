import SwiftUI

struct SettingsHubView: View {
    @Environment(AppSession.self) private var session

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(session.displayName)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Palette.textPrimary)
                        Text(session.tribe?.name ?? "No tribe")
                            .font(.system(size: 14))
                            .foregroundStyle(Palette.textMuted)
                    }
                }

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Coming in this native port")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Palette.textPrimary)
                        Text("Google Sign-In, notifications, legendary-speeches toggle, paywall, legal, and full progress reset remain Flutter-only. Live Firebase is a milestone 2 TODO — the plist is copied, no invented keys.")
                            .font(.system(size: 14))
                            .foregroundStyle(Palette.textMuted)
                            .lineSpacing(3)
                    }
                }

                Button {
                    session.replayOnboarding()
                } label: {
                    Text("Replay onboarding")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Palette.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: Spacing.radiusMd, style: .continuous)
                                .stroke(Palette.hairline, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                Text("Version 1.0 (1)")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.top, Spacing.sm)
            }
            .fueg0ScreenPadding()
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.xxl)
        }
        .background(Palette.background.ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
