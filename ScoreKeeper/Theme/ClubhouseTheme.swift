import SwiftUI

struct ClubhouseTheme {
    static let paper = Color(light: 0xE6E1D3, dark: 0x211711)
    static let paperCard = Color(light: 0xF2EEE2, dark: 0x2E2118)
    static let paperSunken = Color(light: 0xDED8C6, dark: 0x1B1209)
    static let ink = Color(light: 0x33383D, dark: 0xF2E3C2)
    static let inkMuted = Color(light: 0x5F594D, dark: 0xB29578)
    static let felt = Color(light: 0x3F6630, dark: 0xA8B060)
    static let feltDeep = Color(light: 0x2E4F24, dark: 0x2E4F24)
    static let lacquer = Color(light: 0xA93226, dark: 0xE2574B)
    static let brass = Color(light: 0x7A6210, dark: 0xE9A63A)
    static let onFelt = Color(light: 0xF4F2EA, dark: 0xF4F2EA)
    static let primaryFill = Color(light: 0x33383D, dark: 0xF2E3C2)
    static let onPrimary = Color(light: 0xF4F2EA, dark: 0x211711)
    static let panelBorder = Color(light: 0xB8B2A0, dark: 0x4A3626)
    static let woodgrain = Color(light: 0xB8B2A0, dark: 0x5C3D24)
    static let danger = lacquer

    static var rule: Color {
        ink.opacity(0.16)
    }

    static var paperShadow: Color {
        ink.opacity(0.08)
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
