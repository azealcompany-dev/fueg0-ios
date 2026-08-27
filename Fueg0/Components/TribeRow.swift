import SwiftUI

struct TribeRow: View {
    let tribe: Tribe
    let selected: Bool
    var onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: tribe.symbol)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(selected ? Palette.ember : Palette.textSecondary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(tribe.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Palette.textPrimary)
                    Text(tribe.motto)
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.textMuted)
                }

                Spacer()

                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(selected ? Palette.ember : Palette.textMuted)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: Spacing.radiusSm, style: .continuous)
                    .fill(Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.radiusSm, style: .continuous)
                    .stroke(selected ? Palette.emberBorder : Palette.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tribe.name)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

struct Fueg0EmptyState: View {
    let symbol: String
    let title: String
    let copy: String

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Palette.ember)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Palette.surfaceElevated))
                    .overlay(Circle().stroke(Palette.hairline, lineWidth: 1))

                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)

                Text(copy)
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.textMuted)
                    .lineSpacing(3)
            }
        }
    }
}

struct Fueg0ErrorState: View {
    let message: String
    var retryTitle: String = "Try again"
    var onRetry: () -> Void

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Couldn’t load")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
                Text(message)
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.textMuted)
                    .lineSpacing(3)
                Button(retryTitle, action: onRetry)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.ember)
            }
        }
    }
}
