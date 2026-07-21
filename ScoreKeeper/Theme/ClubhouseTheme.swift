import SwiftUI

struct ClubhouseTheme {
    // Warm stock and dense registration-black give every screen the feel of a
    // printed game-night poster rather than a stack of translucent iOS cards.
    static let paper = Color(light: 0xFFF7E5, dark: 0x171510)
    static let paperCard = Color(light: 0xFFFAEE, dark: 0x242018)
    static let paperSunken = Color(light: 0xF0E6CF, dark: 0x100F0C)
    static let ink = Color(light: 0x0A0B0B, dark: 0xFFF7E5)
    static let inkMuted = Color(light: 0x4F504A, dark: 0xC9C1B2)

    // PipCount's Bauhaus primaries. These are also used by player identities,
    // illustration blocks, selection states, and celebratory motion.
    static let blue = Color(light: 0x064BB8, dark: 0x4C8DFF)
    static let red = Color(light: 0xF02A1B, dark: 0xFF5A4D)
    static let yellow = Color(light: 0xFFB600, dark: 0xFFD149)
    static let green = Color(light: 0x00965A, dark: 0x41D58A)

    // Legacy semantic names remain so feature code does not need to know the
    // visual palette. Their values now map into the PipCount system.
    static let felt = blue
    static let feltDeep = Color(light: 0x00388E, dark: 0x2F6FCC)
    static let lacquer = red
    static let brass = yellow
    static let onFelt = Color(light: 0xFFFFFF, dark: 0x07152B)
    static let primaryFill = blue
    static let onPrimary = Color(light: 0xFFFFFF, dark: 0x07152B)
    static let panelBorder = Color(light: 0x242522, dark: 0xDDD3C0)
    static let woodgrain = Color(light: 0xC8BDA6, dark: 0x5C513E)
    static let danger = lacquer

    static var rule: Color {
        ink.opacity(0.22)
    }

    static var ruleStrong: Color {
        ink.opacity(0.72)
    }

    static var paperShadow: Color {
        ink.opacity(0.14)
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
