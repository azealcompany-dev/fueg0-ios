import SwiftUI

struct TribeSelectionView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss

    var isOnboarding: Bool = false
    var onJoined: (() -> Void)? = nil

    @State private var selected: Tribe?
    @State private var joining = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tribe")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.ember)
                    Text("Choose your pack.")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Palette.textPrimary)
                    Text(isOnboarding
                         ? "Seven tribes. One fire. Pick a pack — you can skip and join later."
                         : "Seven tribes. One fire. Pledge a pack to earn points together.")
                        .font(.system(size: 16))
                        .foregroundStyle(Palette.textSecondary)
                        .lineSpacing(4)
                }

                if let errorMessage {
                    Fueg0ErrorState(message: errorMessage) {
                        self.errorMessage = nil
                    }
                }

                LazyVStack(spacing: 8) {
                    ForEach(Tribe.all) { tribe in
                        TribeRow(tribe: tribe, selected: selected?.id == tribe.id) {
                            selected = tribe
                            errorMessage = nil
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    }
                }

                if let selected {
                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(selected.animal.uppercased())
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Palette.ember)
                            Text(selected.traits)
                                .font(.system(size: 15))
                                .foregroundStyle(Palette.textSecondary)
                                .lineSpacing(3)
                            Text("“\(selected.dailyWarCry())”")
                                .font(.system(size: 15).italic())
                                .foregroundStyle(Palette.textMuted)
                                .padding(.top, 2)
                        }
                    }
                }

                EmberButton(
                    title: joining ? "Joining" : (isOnboarding ? "Join the tribe" : "Join this tribe"),
                    enabled: selected != nil && !joining,
                    loading: joining
                ) {
                    Task { await join() }
                }
            }
            .fueg0ScreenPadding()
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.xxl)
        }
        .background(Palette.background.ignoresSafeArea())
        .navigationTitle("Choose tribe")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if selected == nil {
                selected = session.tribe
            }
        }
        .disabled(joining)
    }

    private func join() async {
        guard let selected else { return }
        joining = true
        errorMessage = nil
        defer { joining = false }

        let result = await session.joinTribe(selected)
        switch result {
        case .joined, .alreadyMember:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onJoined?()
            dismiss()
        case .failed(let message):
            errorMessage = message
        }
    }
}
