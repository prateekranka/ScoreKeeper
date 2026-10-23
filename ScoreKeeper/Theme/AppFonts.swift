import SwiftUI

struct AppFonts {
    static let display = Font.system(.largeTitle, design: .default, weight: .black)
    static let largeTitle = Font.system(.largeTitle, design: .default, weight: .black)
    static let hero = Font.system(.largeTitle, design: .default, weight: .black)
    static let title = Font.system(.title2, design: .default, weight: .black)
    static let headline = Font.system(.headline, design: .default, weight: .bold)
    static let tileTitle = Font.system(.title2, design: .default, weight: .black)
    static let body = Font.system(.body, design: .default)
    static let label = Font.system(.body, design: .default, weight: .medium)
    static let caption = label
    static let columnHeader = Font.system(.body, design: .default, weight: .black)
    static let scoreDisplay = Font.system(.largeTitle, design: .default, weight: .black)
    static let scoreMedium = Font.system(.title, design: .default, weight: .black)
    static let scoreSmall = Font.system(.title2, design: .default, weight: .black)
}

struct ColumnHeaderModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(AppFonts.columnHeader)
            .foregroundStyle(ClubhouseTheme.inkMuted)
    }
}

extension View {
    func columnHeaderStyle() -> some View {
        modifier(ColumnHeaderModifier())
    }
}
