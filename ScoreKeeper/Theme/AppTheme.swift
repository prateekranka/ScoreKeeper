import SwiftUI

struct AppTheme {
    static let cornerRadiusSmall: CGFloat = 8
    static let cornerRadiusMedium: CGFloat = 16
    static let cornerRadiusLarge: CGFloat = 24

    static let spacingSmall: CGFloat = 8
    static let spacingMedium: CGFloat = 16
    static let spacingLarge: CGFloat = 24

    static let backgroundGradient = LinearGradient(
        colors: [
            Color(red: 1.0, green: 0.96, blue: 0.92),
            Color(red: 0.95, green: 0.93, blue: 1.0)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let darkBackgroundGradient = LinearGradient(
        colors: [
            Color(red: 0.10, green: 0.10, blue: 0.14),
            Color(red: 0.12, green: 0.10, blue: 0.18)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct AppBackgroundModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(
                (colorScheme == .dark ? AppTheme.darkBackgroundGradient : AppTheme.backgroundGradient)
                    .ignoresSafeArea()
            )
    }
}

extension View {
    func appBackground() -> some View {
        modifier(AppBackgroundModifier())
    }
}
