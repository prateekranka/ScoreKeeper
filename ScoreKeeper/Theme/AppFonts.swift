import SwiftUI

struct AppFonts {
    static let display = Font.system(size: 58, weight: .heavy, design: .rounded)
    static let largeTitle = Font.system(.largeTitle, design: .rounded, weight: .heavy)
    static let hero = Font.system(size: 46, weight: .heavy, design: .rounded)
    static let title = Font.system(.title2, design: .rounded, weight: .bold)
    static let headline = Font.system(.headline, design: .rounded, weight: .semibold)
    static let tileTitle = Font.system(.title2, design: .rounded, weight: .bold)
    static let body = Font.system(.body, design: .rounded)
    static let caption = Font.system(.caption, design: .rounded)
    static let columnHeader = Font.system(.caption, design: .rounded, weight: .bold)
    static let scoreDisplay = Font.system(size: 56, weight: .heavy, design: .rounded)
    static let scoreMedium = Font.system(.title, design: .rounded, weight: .bold)
    static let scoreSmall = Font.system(.title2, design: .rounded, weight: .bold)
}

struct ColumnHeaderModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(AppFonts.columnHeader)
            .textCase(.uppercase)
            .tracking(0.7)
            .foregroundStyle(ClubhouseTheme.inkMuted)
    }
}

extension View {
    func columnHeaderStyle() -> some View {
        modifier(ColumnHeaderModifier())
    }
}
