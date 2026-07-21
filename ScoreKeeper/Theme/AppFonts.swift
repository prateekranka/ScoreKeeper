import SwiftUI

struct AppFonts {
    /// Geometric display voice for Bauhaus brand moments.
    static let display = Font.system(size: 34, weight: .heavy, design: .default)
    static let largeTitle = Font.system(size: 30, weight: .heavy, design: .default)
    static let title = Font.system(.title2, design: .default, weight: .bold)
    static let headline = Font.system(.headline, design: .default, weight: .semibold)
    static let tileTitle = Font.system(.title3, design: .default, weight: .bold)
    static let body = Font.system(.body, design: .default)
    static let caption = Font.system(.caption, design: .default)
    static let columnHeader = Font.system(.caption, design: .default, weight: .bold)
    static let scoreDisplay = Font.system(size: 44, weight: .heavy, design: .rounded)
    static let scoreMedium = Font.system(size: 32, weight: .bold, design: .rounded)
    static let scoreSmall = Font.system(size: 24, weight: .bold, design: .rounded)
}

struct ColumnHeaderModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(AppFonts.columnHeader)
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundStyle(ClubhouseTheme.bauhausBlue)
    }
}

extension View {
    func columnHeaderStyle() -> some View {
        modifier(ColumnHeaderModifier())
    }
}
