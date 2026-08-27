import SwiftUI

enum Palette {
    static let background = Color(hex: 0x0B0908)
    static let surface = Color(hex: 0x161210)
    static let surfaceElevated = Color(hex: 0x1C1612)

    static let ember = Color(hex: 0xFF5A1F)
    static let emberDeep = Color(hex: 0xE03D12)
    static let gold = Color(hex: 0xE8A317)
    static let onEmber = Color(hex: 0x140C08)

    static let textPrimary = Color(hex: 0xF4EDE6)
    static let textSecondary = Color(hex: 0xB5A99F)
    static let textMuted = Color(hex: 0x7A716A)

    static let hairline = Color.white.opacity(0.06)
    static let emberBorder = Color(hex: 0xFF5A1F).opacity(0.28)

    static let success = Color(hex: 0x5C8A5A)
    static let error = Color(hex: 0xC4453A)
}

enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48

    static let screen: CGFloat = 20
    static let radiusSm: CGFloat = 12
    static let radiusMd: CGFloat = 16
    static let radiusLg: CGFloat = 20
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

extension View {
    func fueg0ScreenPadding() -> some View {
        padding(.horizontal, Spacing.screen)
    }
}
