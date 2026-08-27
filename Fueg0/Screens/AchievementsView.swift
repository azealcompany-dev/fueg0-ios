import SwiftUI

struct AchievementsView: View {
    @Environment(AppSession.self) private var session
    @State private var unlocked: Set<String> = []

    var body: some View {
        List {
            Section {
                let count = unlocked.count
                let total = AchievementService.catalog.count
                VStack(alignment: .leading, spacing: 10) {
                    Text("\(count)/\(total) forged")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Palette.textPrimary)
                    ProgressView(value: total == 0 ? 0 : Double(count) / Double(total))
                        .tint(Palette.ember)
                }
                .padding(.vertical, 6)
                .fueg0RowSurface()
            }

            Section("Medals") {
                ForEach(AchievementService.catalog) { item in
                    let done = unlocked.contains(item.id)
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(done ? Palette.onEmber : Palette.textMuted)
                            .frame(width: 36, height: 36)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(done ? Palette.ember : Palette.surfaceElevated)
                            )
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Palette.textPrimary)
                            Text(item.description)
                                .font(.system(size: 13))
                                .foregroundStyle(Palette.textMuted)
                            Text(item.tier.rawValue.uppercased())
                                .font(.system(size: 10, weight: .semibold))
                                .tracking(0.8)
                                .foregroundStyle(done ? Palette.ember : Palette.textMuted)
                        }
                    }
                    .opacity(done ? 1 : 0.55)
                    .fueg0RowSurface()
                }
            }
        }
        .fueg0ListChrome()
        .navigationTitle("Achievements")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            AchievementService.checkAndUnlock(session: session)
            unlocked = AchievementService.unlockedIDs()
        }
    }
}
