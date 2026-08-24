import SwiftUI

struct AppTheme {
    static let cornerRadiusSmall: CGFloat = 12
    static let cornerRadiusMedium: CGFloat = 18
    static let cornerRadiusLarge: CGFloat = 26

    static let spacingSmall: CGFloat = 10
    static let spacingMedium: CGFloat = 16
    static let spacingLarge: CGFloat = 24
    static let spacingXLarge: CGFloat = 32
}

enum AppMotion {
    static let pressIn = Animation.spring(response: 0.18, dampingFraction: 0.88)
    static let pressOut = Animation.spring(response: 0.28, dampingFraction: 0.78)
    static let fade = Animation.easeOut(duration: 0.18)
    static let state = Animation.spring(response: 0.36, dampingFraction: 0.86)
    static let page = Animation.spring(response: 0.46, dampingFraction: 0.90)
    static let theme = Animation.spring(response: 0.42, dampingFraction: 0.84)
    static let criticallyDamped = Animation.spring(response: 0.34, dampingFraction: 1)
    static let celebration = Animation.spring(response: 0.48, dampingFraction: 0.78)
}

struct PipCountPaperBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            ClubhouseTheme.paper

            LinearGradient(
                colors: [
                    ClubhouseTheme.warmHighlight.opacity(colorScheme == .light ? 0.62 : 0.06),
                    Color.clear,
                    ClubhouseTheme.yellow.opacity(colorScheme == .light ? 0.035 : 0.018)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(ClubhouseTheme.coral.opacity(colorScheme == .light ? 0.045 : 0.018))
                .frame(width: 300, height: 300)
                .blur(radius: 52)
                .offset(x: 178, y: -290)

            Circle()
                .fill(ClubhouseTheme.sky.opacity(colorScheme == .light ? 0.10 : 0.035))
                .frame(width: 360, height: 360)
                .blur(radius: 70)
                .offset(x: -190, y: 430)

            PaperGrain()
                .blendMode(colorScheme == .light ? .multiply : .screen)
                .opacity(colorScheme == .light ? 0.30 : 0.12)
        }
    }
}

private struct PaperGrain: View {
    var body: some View {
        Canvas { context, size in
            var row = 0
            var y: CGFloat = 4
            while y < size.height {
                var column = 0
                var x: CGFloat = 4
                while x < size.width {
                    let phase = CGFloat((row * 7 + column * 11) % 9)
                    let diameter: CGFloat = Int(phase).isMultiple(of: 3) ? 0.9 : 0.55
                    let rect = CGRect(
                        x: x + phase.truncatingRemainder(dividingBy: 2.4),
                        y: y + phase.truncatingRemainder(dividingBy: 1.8),
                        width: diameter,
                        height: diameter
                    )
                    context.fill(Path(ellipseIn: rect), with: .color(ClubhouseTheme.ink.opacity(0.12)))
                    column += 1
                    x += 13
                }
                row += 1
                y += 13
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct AppBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(PipCountPaperBackground().ignoresSafeArea())
    }
}

extension View {
    func appBackground() -> some View {
        modifier(AppBackgroundModifier())
    }
}
