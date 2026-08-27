import SwiftUI

struct IgniteView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    Text("Today’s fire")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.ember)

                    Text("The ritual is still in Flutter.")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Palette.textPrimary)

                    Text("Daily Fire video, Hell Fire, and streak lock ship next in this native port. For now, here is today’s WOD so the shell still feels like the product.")
                        .font(.system(size: 16))
                        .foregroundStyle(Palette.textSecondary)
                        .lineSpacing(4)

                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(SampleContent.todaysWODTitle)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(Palette.textPrimary)
                            Text(SampleContent.todaysWODDetail)
                                .font(.system(size: 15))
                                .foregroundStyle(Palette.textSecondary)
                                .lineSpacing(4)
                        }
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Palette.textSecondary)
                }
            }
        }
    }
}
