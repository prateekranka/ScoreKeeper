import SwiftUI

struct ClubhouseTheme {
    // Paper Bauhaus. A warm printed-paper field (light) and a near-black studio
    // paper (dark) carry a hard-edged ink grid; ultramarine is the single accent
    // and Bauhaus primaries are reserved for player identity and status.
    static let paper = Color(light: 0xF0F0E4, dark: 0x121218)
    static let paperCard = Color(light: 0xFCF6F0, dark: 0x1A1F26)
    static let paperSunken = Color(light: 0xE9E5D8, dark: 0x14171C)
    static let ink = Color(light: 0x171712, dark: 0xF0F0E4)
    static let inkMuted = Color(light: 0x7C766A, dark: 0xA2A296)

    // PipCount's Bauhaus primaries. These are also used by player identities,
    // illustration blocks, selection states, and celebratory motion.
    // Final primary interaction token. Keep ultramarine distinct from player blue.
    static let blue = Color(light: 0x0036A8, dark: 0x6E9BFF)
    static let blueDeep = Color(light: 0x002A78, dark: 0x4B78E8)
    static let red = Color(light: 0xDE181E, dark: 0xFC5A60)
    static let yellow = Color(light: 0xFCB412, dark: 0xFCD248)
    static let green = Color(light: 0x008A42, dark: 0x3CCC78)
    static let sky = Color(light: 0xCCDEEA, dark: 0x1D2F52)

    // Legacy semantic names remain so feature code does not need to know the
    // visual palette. Their values now map into the PipCount system.
    static let felt = blue
    static let feltDeep = blueDeep
    static let lacquer = red
    // Darker than the illustration yellow so gold text and score labels remain
    // readable on cream stock; bright gold on the dark paper.
    static let brass = Color(light: 0x8A6200, dark: 0xFCD248)
    static let onFelt = Color(light: 0xFFFFFF, dark: 0x07152B)
    static let primaryFill = blue
    static let onPrimary = Color(light: 0xFFFFFF, dark: 0x07152B)
    static let panelBorder = Color(light: 0xE4DED2, dark: 0x2A3038)
    static let woodgrain = Color(light: 0xD8D2C2, dark: 0x3A3F47)
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
