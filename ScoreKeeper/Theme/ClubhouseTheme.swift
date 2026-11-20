import SwiftUI

struct ClubhouseTheme {
    // MARK: Paper and ink

    static let paper = Color(light: 0xF6F2E8, dark: 0x111216)
    static let paperCard = Color(light: 0xFFFDF7, dark: 0x1A1C21)
    static let paperSunken = Color(light: 0xECE7DC, dark: 0x15171B)
    static let paperElevated = Color(light: 0xFFFFFF, dark: 0x202228)
    static let ink = Color(light: 0x0B0B0B, dark: 0xF7F3E9)
    static let inkMuted = Color(light: 0x5B554D, dark: 0xC2BCB2)

    // MARK: PipCount Bauhaus palette (raw — Theme files, artwork and PipTint only)

    static let blue = Color(light: 0x0C42CD, dark: 0x7DA1FF)
    static let blueDeep = Color(light: 0x07349F, dark: 0x7DA1FF)
    static let red = Color(light: 0xA51124, dark: 0xFF929B)
    static let yellow = Color(light: 0xFFB512, dark: 0xFFD45D)
    static let green = Color(light: 0x005D2D, dark: 0x76D69D)
    static let sky = Color(light: 0xD7E7F7, dark: 0x243246)
    static let coral = Color(light: 0xFF775E, dark: 0xFF9A85)
    static let lilac = Color(light: 0xA79AD1, dark: 0xC8BDF0)

    static func onButton(_ color: Color) -> Color {
        if color == ink { return paperCard }
        if color == yellow { return onYellow }
        return onPrimary
    }

    static let palette: [Color] = [blue, red, yellow, green, ink]

    // MARK: Legacy names — do not use in new code; use the role tokens below

    static let felt = blue
    static let feltDeep = blueDeep
    static let lacquer = red
    static let brass = Color(light: 0x704A00, dark: 0xFFD45D)
    static let onYellow = Color(light: 0x0B0B0B, dark: 0x0B0B0B)
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

    // MARK: Role tokens — feature code uses ONLY these
    // Each role names a job, not a look. The palette above feeds them.
    // Matches the CSS names in the PipCount Component Library
    // (--surface-card -> surfaceCard, --accent-primary -> accentPrimary).

    // Surfaces
    static let surfacePage = paper
    static let surfaceCard = paperCard
    static let surfaceSunken = paperSunken
    static let surfaceRaised = paperElevated

    // Text
    static let textPrimary = ink
    static let textSecondary = inkMuted
    static let textOnAccent = onPrimary
    static let textOnHighlight = onYellow
    static let textLink = blue

    // Lines
    static var borderHairline: Color { rule }
    static var borderStrong: Color { ruleStrong }
    static let borderPanel = panelBorder
    static let borderWood = woodgrain
    static let borderFocus = blue

    // Accents and states
    static let accentPrimary = blue
    static let accentPrimaryStrong = blueDeep
    static let accentDanger = red
    static let accentLacquer = red
    static let accentHighlight = yellow
    static let accentLeader = brass

    // Shadows and effects
    static var shadowCard: Color { paperShadow }
    static var shadowArt: Color { artShadow }
    static var effectSheen: Color { warmHighlight }
    static let artBackdrop = sky

    /// Text color for a filled button or chip: textOnHighlight on yellow,
    /// surfaceCard on ink, textOnAccent on everything else.
    static func textOn(_ tint: PipTint) -> Color {
        switch tint {
        case .yellow: return textOnHighlight
        case .ink: return surfaceCard
        default: return textOnAccent
        }
    }
}

/// The only way to pass a palette color into a component.
/// A component that shows a game, a round or a player takes a PipTint,
/// never a free `Color`. This keeps every tint inside the palette.
enum PipTint: CaseIterable, Hashable {
    case blue, red, yellow, green, orange, brown, teal, pink, ink

    var color: Color {
        switch self {
        case .blue: return ClubhouseTheme.blue
        case .red: return ClubhouseTheme.red
        case .yellow: return ClubhouseTheme.yellow
        case .green: return ClubhouseTheme.green
        case .orange: return PlayerColors.palette[4]
        case .brown: return PlayerColors.palette[5]
        case .teal: return PlayerColors.palette[6]
        case .pink: return PlayerColors.palette[7]
        case .ink: return ClubhouseTheme.ink
        }
    }

    /// Seat tints in seat order: seat 1 is blue, seat 8 is pink.
    static let seats: [PipTint] = [.blue, .red, .yellow, .green, .orange, .brown, .teal, .pink]
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
