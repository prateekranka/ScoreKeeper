import SwiftUI

struct PlayerColors {
    static let palette: [Color] = [
        ClubhouseTheme.blue,
        ClubhouseTheme.red,
        ClubhouseTheme.yellow,
        ClubhouseTheme.green,
        Color(light: 0xE75C16, dark: 0xFF8B4A),
        Color(light: 0x7447B8, dark: 0xA986F0),
        Color(light: 0x00838F, dark: 0x56C8D2),
        Color(light: 0xD43A73, dark: 0xF27AA4),
    ]

    private static let glyphs = ["●", "■", "▲", "◆", "✦", "✚", "◗", "⬢"]

    static func color(for index: Int) -> Color {
        palette[index % palette.count]
    }

    static func lightColor(for index: Int) -> Color {
        color(for: index).opacity(0.12)
    }

    static func glyph(for index: Int) -> String {
        glyphs[index % glyphs.count]
    }
}
