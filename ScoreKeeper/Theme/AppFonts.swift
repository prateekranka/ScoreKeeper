import SwiftUI

struct AppFonts {
    static let display = Font.custom("Press Start 2P", size: 22, relativeTo: .largeTitle)
    static let largeTitle = Font.custom("Press Start 2P", size: 20, relativeTo: .largeTitle)
    static let title = Font.system(.title2, design: .default, weight: .bold)
    static let headline = Font.system(.headline, design: .default, weight: .semibold)
    static let tileTitle = Font.custom("Press Start 2P", size: 12, relativeTo: .title3)
    static let body = Font.system(.body, design: .default)
    static let caption = Font.system(.caption, design: .default)
    static let columnHeader = Font.system(.caption, design: .default, weight: .semibold)
    static let scoreDisplay = Font.custom("VT323", size: 44, relativeTo: .largeTitle)
    static let scoreMedium = Font.custom("VT323", size: 32, relativeTo: .title)
    static let scoreSmall = Font.custom("VT323", size: 24, relativeTo: .title3)
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
