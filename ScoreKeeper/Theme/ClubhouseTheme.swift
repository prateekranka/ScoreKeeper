import SwiftUI

struct ClubhouseTheme {
    static let paper = Color(light: 0xF6F1E7, dark: 0x15181B)
    static let paperCard = Color(light: 0xFCF9F2, dark: 0x1E2226)
    static let paperSunken = Color(light: 0xEFE8DA, dark: 0x14161A)
    static let ink = Color(light: 0x26221A, dark: 0xEDE7DA)
    static let inkMuted = Color(light: 0x6F6757, dark: 0x9A937F)
    static let felt = Color(light: 0x1E5240, dark: 0x4E8A6E)
    static let feltDeep = Color(light: 0x163D30, dark: 0x163D30)
    static let lacquer = Color(light: 0xB44A3B, dark: 0xCE6A56)
    static let brass = Color(light: 0xA0803D, dark: 0xC2A254)
    static let onFelt = Color(light: 0xF6F1E7, dark: 0xF6F1E7)

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
