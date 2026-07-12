import SwiftUI

struct PlayerColors {
    static let palette: [Color] = [
        Color(light: 0x5D538F, dark: 0xE9A63A),
        Color(light: 0x2F5E93, dark: 0xE0662E),
        Color(light: 0x3F6630, dark: 0xA8B060),
        Color(light: 0x8A4E2A, dark: 0xD89B6A),
        Color(light: 0x7A6210, dark: 0xF2C94C),
        Color(light: 0x555B60, dark: 0xC9B8A0),
        Color(light: 0x7C3A55, dark: 0xC97B8E),
        Color(light: 0x2F6E6A, dark: 0x7FBDB5),
    ]

    private static let glyphs = ["◆", "●", "▲", "■", "★", "✚", "◗", "⬢"]

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
