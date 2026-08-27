import SwiftUI

struct SettingsHubView: View {
    @Environment(AppSession.self) private var session
    @State private var showTribeSelection = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(session.displayName)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Palette.textPrimary)
                        Text(session.userEmail ?? session.tribe?.name ?? "No tribe")
                            .font(.system(size: 14))
                            .foregroundStyle(Palette.textMuted)
                        if session.userEmail != nil, let tribe = session.tribe {
                            Text(tribe.name)
                                .font(.system(size: 14))
                                .foregroundStyle(Palette.textMuted)
                        }
                    }
                }

                SurfaceCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Account")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Palette.textPrimary)
                        Text("Signed in with email/password or Google. Warrior name lives on this device and in Firestore users/{uid}.")
                            .font(.system(size: 14))
                            .foregroundStyle(Palette.textMuted)
                            .lineSpacing(3)
                    }
                }

                if session.tribe == nil {
                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tribe")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Palette.textPrimary)
                            Text("You have not pledged a pack yet. Join one of the seven tribes to earn points together.")
                                .font(.system(size: 14))
                                .foregroundStyle(Palette.textMuted)
                                .lineSpacing(3)
                        }
                    }
                    EmberButton(title: "Choose a tribe") {
                        showTribeSelection = true
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

                Button {
                    session.signOut()
                } label: {
                    Text("Sign out")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Palette.error)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: Spacing.radiusMd, style: .continuous)
                                .stroke(Palette.error.opacity(0.35), lineWidth: 1)
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
        .sheet(isPresented: $showTribeSelection) {
            NavigationStack {
                TribeSelectionView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showTribeSelection = false }
                                .foregroundStyle(Palette.textSecondary)
                        }
                    }
            }
            .preferredColorScheme(.dark)
        }
    }
}
