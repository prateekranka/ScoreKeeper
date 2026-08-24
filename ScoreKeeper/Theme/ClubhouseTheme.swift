import SwiftUI

struct ClubhouseTheme {
    // MARK: Paper and ink

    static let paper = Color(light: 0xF6F2E8, dark: 0x111216)
    static let paperCard = Color(light: 0xFFFDF7, dark: 0x1A1C21)
    static let paperSunken = Color(light: 0xECE7DC, dark: 0x15171B)
    static let paperElevated = Color(light: 0xFFFFFF, dark: 0x202228)
    static let ink = Color(light: 0x0B0B0B, dark: 0xF7F3E9)
    static let inkMuted = Color(light: 0x756F65, dark: 0xAAA49B)

    // MARK: PipCount Bauhaus palette

    static let blue = Color(light: 0x0D47D9, dark: 0x6F96FF)
    static let blueDeep = Color(light: 0x07349F, dark: 0x4F73D4)
    static let red = Color(light: 0xEF3340, dark: 0xFF6E78)
    static let yellow = Color(light: 0xFFB512, dark: 0xFFD45D)
    static let green = Color(light: 0x0A8F4B, dark: 0x59C987)
    static let sky = Color(light: 0xD7E7F7, dark: 0x243246)
    static let coral = Color(light: 0xFF775E, dark: 0xFF9A85)
    static let lilac = Color(light: 0xA79AD1, dark: 0xC8BDF0)

    static let palette: [Color] = [blue, red, yellow, green, ink]

    // MARK: Stable semantic names used throughout feature code

    static let felt = blue
    static let feltDeep = blueDeep
    static let lacquer = red
    static let brass = Color(light: 0x9A6900, dark: 0xFFD45D)
    static let onFelt = Color(light: 0xFFFFFF, dark: 0x10131A)
    static let primaryFill = blue
    static let onPrimary = Color(light: 0xFFFFFF, dark: 0x0B0E16)
    static let panelBorder = Color(light: 0xD8D1C5, dark: 0x353840)
    static let woodgrain = Color(light: 0xC9B99F, dark: 0x40372F)
    static let danger = red

    static var rule: Color {
        ink.opacity(0.115)
    }

    static var ruleStrong: Color {
        ink.opacity(0.40)
    }

    static var paperShadow: Color {
        Color(light: 0x41352A, dark: 0x000000).opacity(0.17)
    }

    static var artShadow: Color {
        Color(light: 0x2B241D, dark: 0x000000).opacity(0.20)
    }

    static var warmHighlight: Color {
        Color(light: 0xFFFFFF, dark: 0xFFFFFF).opacity(0.68)
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
