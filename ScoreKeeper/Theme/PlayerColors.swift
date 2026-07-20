import SwiftUI

enum PlayerShape: CaseIterable {
    case circle
    case square
    case triangle
    case diamond
    case star
    case plus
    case capsule
    case hexagon

    var systemName: String {
        switch self {
        case .circle: return "circle.fill"
        case .square: return "square.fill"
        case .triangle: return "triangle.fill"
        case .diamond: return "diamond.fill"
        case .star: return "star.fill"
        case .plus: return "plus"
        case .capsule: return "capsule.fill"
        case .hexagon: return "hexagon.fill"
        }
    }
}

struct PlayerColors {
    /// Bauhaus primary player palette: blue, red, yellow, green, then supporting tones.
    static let palette: [Color] = [
        ClubhouseTheme.bauhausBlue,
        ClubhouseTheme.bauhausRed,
        ClubhouseTheme.bauhausYellow,
        ClubhouseTheme.bauhausGreen,
        Color(light: 0x1A1A1A, dark: 0xF0EDE4),
        Color(light: 0x5C6BC0, dark: 0x9FA8DA),
        Color(light: 0x00838F, dark: 0x4DD0E1),
        Color(light: 0x6A1B9A, dark: 0xCE93D8),
    ]

    private static let shapes: [PlayerShape] = PlayerShape.allCases

    static func color(for index: Int) -> Color {
        palette[index % palette.count]
    }

    static func lightColor(for index: Int) -> Color {
        color(for: index).opacity(0.12)
    }

    static func shape(for index: Int) -> PlayerShape {
        shapes[index % shapes.count]
    }

    static func glyph(for index: Int) -> String {
        switch shape(for: index) {
        case .circle: return "●"
        case .square: return "■"
        case .triangle: return "▲"
        case .diamond: return "◆"
        case .star: return "★"
        case .plus: return "✚"
        case .capsule: return "◗"
        case .hexagon: return "⬢"
        }
    }
}
