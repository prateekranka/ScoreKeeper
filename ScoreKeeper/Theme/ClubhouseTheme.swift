import SwiftUI

struct ClubhouseTheme {
    static let paper = Color(light: 0xF4F2EC, dark: 0x151310)
    static let paperCard = Color(light: 0xFFFDF8, dark: 0x211E19)
    static let paperSunken = Color(light: 0xEAE6DC, dark: 0x100F0D)
    static let ink = Color(light: 0x242522, dark: 0xF5F1E8)
    static let inkMuted = Color(light: 0x65645E, dark: 0xB9B2A6)
    static let felt = Color(light: 0x2F664B, dark: 0x74B58E)
    static let feltDeep = Color(light: 0x244F3A, dark: 0x4B8D68)
    static let lacquer = Color(light: 0xA73D32, dark: 0xF07164)
    static let brass = Color(light: 0x80661C, dark: 0xE4B44A)
    static let onFelt = Color(light: 0xFFFFFF, dark: 0x102016)
    static let primaryFill = Color(light: 0x242522, dark: 0xF5F1E8)
    static let onPrimary = Color(light: 0xFFFFFF, dark: 0x151310)
    static let panelBorder = Color(light: 0xCBC6BA, dark: 0x403A32)
    static let woodgrain = Color(light: 0xCBC6BA, dark: 0x584634)
    static let danger = lacquer

    static var rule: Color {
        ink.opacity(0.14)
    }

    static var paperShadow: Color {
        ink.opacity(0.10)
    }
}

extension Color {
    init(light: UInt, dark: UInt) {
        self.init(UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
