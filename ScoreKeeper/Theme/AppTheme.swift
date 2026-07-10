import SwiftUI

struct AppTheme {
    static let cornerRadiusSmall: CGFloat = 2
    static let cornerRadiusMedium: CGFloat = 4
    static let cornerRadiusLarge: CGFloat = 6

    static let spacingSmall: CGFloat = 8
    static let spacingMedium: CGFloat = 16
    static let spacingLarge: CGFloat = 24
    static let spacingXLarge: CGFloat = 32
}

struct AppBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(ClubhouseTheme.paper.ignoresSafeArea())
    }
}

extension View {
    func appBackground() -> some View {
        modifier(AppBackgroundModifier())
    }
}
