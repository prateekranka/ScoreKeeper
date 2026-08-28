import SwiftUI

struct AppFonts {
    // A neutral grotesk system replaces the rounded display treatment. It
    // keeps the approved Bauhaus reference sharp while retaining Dynamic Type.
    static let display = Font.system(size: 62, weight: .black, design: .default)
    static let largeTitle = Font.system(.largeTitle, design: .default, weight: .black)
    static let hero = Font.system(size: 48, weight: .black, design: .default)
    static let title = Font.system(.title2, design: .default, weight: .black)
    static let headline = Font.system(.headline, design: .default, weight: .bold)
    static let tileTitle = Font.system(.title2, design: .default, weight: .black)
    static let body = Font.system(.body, design: .default)
    static let caption = Font.system(.caption, design: .default)
    static let columnHeader = Font.system(.caption, design: .default, weight: .black)
    static let scoreDisplay = Font.system(size: 58, weight: .black, design: .default)
    static let scoreMedium = Font.system(.title, design: .default, weight: .black)
    static let scoreSmall = Font.system(.title2, design: .default, weight: .black)
}

struct ColumnHeaderModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(AppFonts.columnHeader)
            .textCase(.uppercase)
            .tracking(1.05)
            .foregroundStyle(ClubhouseTheme.inkMuted)
    }
}

extension View {
    func columnHeaderStyle() -> some View {
        modifier(ColumnHeaderModifier())
    }
}
