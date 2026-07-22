import SwiftUI

/// Bauhaus / Swiss-modern PipCount palette.
/// Kept as `ClubhouseTheme` so existing call sites migrate without a rename churn.
struct ClubhouseTheme {
    // Surfaces
    static let paper = Color(light: 0xF5F2E8, dark: 0x12141A)
    static let paperCard = Color(light: 0xFFFAF3, dark: 0x1C1F28)
    static let paperSunken = Color(light: 0xEBE6DA, dark: 0x0C0E14)

    // Ink
    static let ink = Color(light: 0x0B0B0B, dark: 0xF5F2E8)
    static let inkMuted = Color(light: 0x6B675E, dark: 0xA8A296)

    // Primary Bauhaus set
    static let bauhausBlue = Color(light: 0x0038A8, dark: 0x4D7FE8)
    static let bauhausBlueDeep = Color(light: 0x002A7A, dark: 0x3566C9)
    static let bauhausRed = Color(light: 0xE31B23, dark: 0xFF5A5F)
    static let bauhausYellow = Color(light: 0xFDB913, dark: 0xFFD24A)
    static let bauhausGreen = Color(light: 0x008A45, dark: 0x3DCF7A)

    // Semantic aliases used across the app
    static let felt = bauhausBlue
    static let feltDeep = bauhausBlueDeep
    static let lacquer = bauhausRed
    static let brass = bauhausYellow
    static let onFelt = Color(light: 0xFFFFFF, dark: 0xFFFFFF)
    static let primaryFill = bauhausBlue
    static let onPrimary = Color(light: 0xFFFFFF, dark: 0xFFFFFF)
    static let panelBorder = Color(light: 0xD6D0C4, dark: 0x3A3F4C)
    static let woodgrain = Color(light: 0xC9C2B4, dark: 0x4A5160)
    static let danger = bauhausRed

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
