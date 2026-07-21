import SwiftUI

struct AppTheme {
    static let cornerRadiusSmall: CGFloat = 14
    static let cornerRadiusMedium: CGFloat = 18
    static let cornerRadiusLarge: CGFloat = 24

    static let spacingSmall: CGFloat = 8
    static let spacingMedium: CGFloat = 16
    static let spacingLarge: CGFloat = 24
    static let spacingXLarge: CGFloat = 32
}

enum AppMotion {
    static let pressIn = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.10)
    static let pressOut = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.14)
    static let fade = Animation.easeOut(duration: 0.16)
    static let state = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.18)
    static let page = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.24)
    static let theme = Animation.timingCurve(0.77, 0, 0.175, 1, duration: 0.22)
    static let criticallyDamped = Animation.spring(response: 0.34, dampingFraction: 1)
    /// Occasional screen entrances — short enough for Home, expressive enough for Game Over.
    static let entrance = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.22)
    static let staggerStep: Double = 0.04
}

struct AppBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    ClubhouseTheme.paper
                    BauhausCornerTexture()
                        .allowsHitTesting(false)
                }
                .ignoresSafeArea()
            }
    }
}

extension View {
    func appBackground() -> some View {
        modifier(AppBackgroundModifier())
    }
}
