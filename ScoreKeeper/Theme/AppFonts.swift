import SwiftUI

struct AppFonts {
    static let display = Font.custom("Press Start 2P", size: 22, relativeTo: .largeTitle)
    static let largeTitle = Font.custom("Press Start 2P", size: 22, relativeTo: .largeTitle)
    static let title = Font.custom("Press Start 2P", size: 15, relativeTo: .title2)
    static let headline = Font.custom("Press Start 2P", size: 11, relativeTo: .headline)
    static let tileTitle = Font.custom("Press Start 2P", size: 12, relativeTo: .title3)
    static let body = Font.custom("VT323", size: 19, relativeTo: .body)
    static let caption = Font.custom("VT323", size: 15, relativeTo: .caption)
    static let columnHeader = Font.custom("VT323", size: 14, relativeTo: .caption2)
    static let scoreDisplay = Font.custom("VT323", size: 44, relativeTo: .largeTitle)
    static let scoreMedium = Font.custom("VT323", size: 32, relativeTo: .title)
    static let scoreSmall = Font.custom("VT323", size: 24, relativeTo: .title3)
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
