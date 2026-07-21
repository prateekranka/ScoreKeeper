import SwiftUI

struct AppFonts {
    static let display = Font.system(.largeTitle, design: .default, weight: .black).width(.condensed)
    static let largeTitle = Font.system(.largeTitle, design: .default, weight: .black).width(.condensed)
    static let hero = Font.system(.largeTitle, design: .default, weight: .black).width(.condensed)
    static let title = Font.system(.title2, design: .default, weight: .black).width(.condensed)
    static let headline = Font.system(.headline, design: .default, weight: .bold).width(.condensed)
    static let tileTitle = Font.system(.title2, design: .default, weight: .black).width(.condensed)
    static let body = Font.system(.body, design: .default)
    static let caption = Font.system(.caption, design: .default)
    static let columnHeader = Font.system(.caption, design: .default, weight: .black).width(.condensed)
    static let scoreDisplay = Font.system(.largeTitle, design: .default, weight: .black).width(.condensed)
    static let scoreMedium = Font.system(.title, design: .default, weight: .black).width(.condensed)
    static let scoreSmall = Font.system(.title2, design: .default, weight: .black).width(.condensed)
}

struct ColumnHeaderModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(AppFonts.columnHeader)
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundStyle(ClubhouseTheme.inkMuted)
    }
}

extension View {
    func columnHeaderStyle() -> some View {
        modifier(ColumnHeaderModifier())
    }
}
