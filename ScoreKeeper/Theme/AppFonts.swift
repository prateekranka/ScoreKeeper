import SwiftUI

struct AppFonts {
    static let display = Font.system(.largeTitle, design: .serif, weight: .bold)
    static let largeTitle = Font.system(.largeTitle, design: .serif, weight: .bold)
    static let title = Font.system(.title2, design: .serif, weight: .bold)
    static let headline = Font.system(.headline, design: .default, weight: .semibold)
    static let body = Font.system(.body, design: .default)
    static let caption = Font.system(.caption, design: .default)
    static let columnHeader = Font.system(.caption2, design: .default, weight: .semibold)
    static let scoreDisplay = Font.system(.largeTitle, design: .default, weight: .heavy)
    static let scoreMedium = Font.system(.title, design: .default, weight: .heavy)
    static let scoreSmall = Font.system(.title3, design: .default, weight: .heavy)
}

struct ColumnHeaderModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(AppFonts.columnHeader)
            .textCase(.uppercase)
            .tracking(1.4)
            .foregroundStyle(ClubhouseTheme.inkMuted)
    }
}

extension View {
    func columnHeaderStyle() -> some View {
        modifier(ColumnHeaderModifier())
    }
}
