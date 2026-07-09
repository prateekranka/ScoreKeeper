import SwiftUI

struct PlayerColors {
    static let palette: [Color] = [
        Color(light: 0xC0554A, dark: 0xD87369), // Lacquer
        Color(light: 0x2E6B52, dark: 0x4B8B70), // Pine
        Color(light: 0xA9843B, dark: 0xC7A95E), // Brass
        Color(light: 0x34557E, dark: 0x5878A0), // Navy
        Color(light: 0xBC7434, dark: 0xD79254), // Terracotta
        Color(light: 0x6E4B72, dark: 0x906D94), // Plum
        Color(light: 0x3F7C86, dark: 0x62A0AA), // Slate teal
        Color(light: 0x8E4A5B, dark: 0xAD6E7D), // Rosewood
    ]

    static func color(for index: Int) -> Color {
        palette[index % palette.count]
    }

    static func lightColor(for index: Int) -> Color {
        color(for: index).opacity(0.12)
    }
}
