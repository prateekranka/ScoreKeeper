import SwiftUI

struct ClubhouseTheme {
    // A warm, tactile tabletop palette. The UI should feel like stationery and
    // game pieces arranged for a real evening with friends rather than a rigid
    // poster grid.
    static let paper = Color(light: 0xF4F0E7, dark: 0x121316)
    static let paperCard = Color(light: 0xFFFBF4, dark: 0x1B1C20)
    static let paperSunken = Color(light: 0xEAE4D8, dark: 0x16181C)
    static let ink = Color(light: 0x24211E, dark: 0xF5F1E8)
    static let inkMuted = Color(light: 0x776F65, dark: 0xAAA39A)

    // Friendly editorial accents inspired by printed game boxes, pencils,
    // score sheets, and ceramic snack bowls.
    static let blue = Color(light: 0x315BA8, dark: 0x82A8FF)
    static let blueDeep = Color(light: 0x20427C, dark: 0x5F84D9)
    static let red = Color(light: 0xD95B45, dark: 0xFF806C)
    static let yellow = Color(light: 0xE5A83D, dark: 0xF4C568)
    static let green = Color(light: 0x4C7B63, dark: 0x79B595)
    static let sky = Color(light: 0xC9DCDF, dark: 0x243746)
    static let coral = Color(light: 0xEF8F72, dark: 0xFFAA92)
    static let lilac = Color(light: 0xA69BC7, dark: 0xC5B9EA)

    // Existing semantic names remain stable for feature code.
    static let felt = blue
    static let feltDeep = blueDeep
    static let lacquer = red
    static let brass = Color(light: 0x9A6A12, dark: 0xF4C568)
    static let onFelt = Color(light: 0xFFFFFF, dark: 0x11151F)
    static let primaryFill = blue
    static let onPrimary = Color(light: 0xFFFFFF, dark: 0x101521)
    static let panelBorder = Color(light: 0xD9D0C1, dark: 0x35363C)
    static let woodgrain = Color(light: 0xCDBAA0, dark: 0x40372F)
    static let danger = red

    static var rule: Color {
        ink.opacity(0.12)
    }

    static var ruleStrong: Color {
        ink.opacity(0.42)
    }

    static var paperShadow: Color {
        Color(light: 0x5A4534, dark: 0x000000).opacity(0.16)
    }

    static var warmHighlight: Color {
        Color(light: 0xFFFFFF, dark: 0xFFFFFF).opacity(0.64)
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
