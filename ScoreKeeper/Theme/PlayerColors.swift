import SwiftUI

struct PlayerColors {
    static let palette: [Color] = [
        Color(red: 1.0, green: 0.42, blue: 0.42),   // Coral Red
        Color(red: 0.31, green: 0.80, blue: 0.77),   // Teal
        Color(red: 1.0, green: 0.85, blue: 0.24),    // Sunny Yellow
        Color(red: 0.42, green: 0.36, blue: 0.91),   // Purple
        Color(red: 1.0, green: 0.54, blue: 0.36),    // Orange
        Color(red: 0.66, green: 0.90, blue: 0.81),   // Mint Green
    ]

    static func color(for index: Int) -> Color {
        palette[index % palette.count]
    }

    static func lightColor(for index: Int) -> Color {
        color(for: index).opacity(0.2)
    }
}
