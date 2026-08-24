import SwiftUI

struct AppTheme {
    static let cornerRadiusSmall: CGFloat = 12
    static let cornerRadiusMedium: CGFloat = 18
    static let cornerRadiusLarge: CGFloat = 28
    static let cornerRadiusXLarge: CGFloat = 36

    static let spacingXSmall: CGFloat = 6
    static let spacingSmall: CGFloat = 10
    static let spacingMedium: CGFloat = 16
    static let spacingLarge: CGFloat = 24
    static let spacingXLarge: CGFloat = 32
    static let spacingXXLarge: CGFloat = 44

    /// Keeps phone layouts generous while allowing iPad screens to use the
    /// extra room instead of stretching every card edge to edge.
    static let contentMaxWidth: CGFloat = 1_080
    static let formMaxWidth: CGFloat = 760
    static let compactArtHeight: CGFloat = 176
    static let heroArtHeight: CGFloat = 248
    static let regularHeroArtHeight: CGFloat = 330
}

enum AppMotion {
    static let pressIn = Animation.spring(response: 0.16, dampingFraction: 0.90)
    static let pressOut = Animation.spring(response: 0.28, dampingFraction: 0.78)
    static let fade = Animation.easeOut(duration: 0.18)
    static let state = Animation.spring(response: 0.38, dampingFraction: 0.84)
    static let page = Animation.spring(response: 0.52, dampingFraction: 0.88)
    static let theme = Animation.spring(response: 0.44, dampingFraction: 0.82)
    static let criticallyDamped = Animation.spring(response: 0.34, dampingFraction: 1)
    static let celebration = Animation.spring(response: 0.58, dampingFraction: 0.74)
    static let artEntrance = Animation.spring(response: 0.68, dampingFraction: 0.78)
    static let artExit = Animation.easeInOut(duration: 0.18)
}

private struct PipCountPageIsExitingKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Set by the root router just before a programmatic navigation change so
    /// large page artwork can resolve its composition before the screen moves.
    var pipCountPageIsExiting: Bool {
        get { self[PipCountPageIsExitingKey.self] }
        set { self[PipCountPageIsExitingKey.self] = newValue }
    }
}

struct PipCountPaperBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            ClubhouseTheme.paper

            LinearGradient(
                colors: [
                    ClubhouseTheme.warmHighlight.opacity(colorScheme == .light ? 0.72 : 0.055),
                    Color.clear,
                    ClubhouseTheme.yellow.opacity(colorScheme == .light ? 0.025 : 0.012)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Very quiet geometry connects every screen without competing
            // with the foreground kinetic compositions.
            Circle()
                .stroke(ClubhouseTheme.blue.opacity(colorScheme == .light ? 0.045 : 0.028), lineWidth: 1)
                .frame(width: 430, height: 430)
                .offset(x: -225, y: -330)

            Circle()
                .stroke(ClubhouseTheme.ink.opacity(colorScheme == .light ? 0.035 : 0.025), lineWidth: 1)
                .frame(width: 620, height: 620)
                .offset(x: 270, y: 430)

            Rectangle()
                .fill(ClubhouseTheme.red.opacity(colorScheme == .light ? 0.024 : 0.012))
                .frame(width: 210, height: 210)
                .rotationEffect(.degrees(16))
                .blur(radius: 34)
                .offset(x: 240, y: -350)

            PaperGrain()
                .blendMode(colorScheme == .light ? .multiply : .screen)
                .opacity(colorScheme == .light ? 0.22 : 0.08)
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
                    let diameter: CGFloat = Int(phase).isMultiple(of: 3) ? 0.85 : 0.48
                    let rect = CGRect(
                        x: x + phase.truncatingRemainder(dividingBy: 2.4),
                        y: y + phase.truncatingRemainder(dividingBy: 1.8),
                        width: diameter,
                        height: diameter
                    )
                    context.fill(Path(ellipseIn: rect), with: .color(ClubhouseTheme.ink.opacity(0.10)))
                    column += 1
                    x += 14
                }
                row += 1
                y += 14
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct AppBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(PipCountPaperBackground().ignoresSafeArea())
    }
}

private struct PipCountPageContentModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let requestedMaxWidth: CGFloat?

    func body(content: Content) -> some View {
        let width = requestedMaxWidth ?? (horizontalSizeClass == .regular ? AppTheme.contentMaxWidth : .infinity)

        content
            .frame(maxWidth: width, alignment: .top)
            .frame(maxWidth: .infinity, alignment: .top)
    }
}

extension View {
    func appBackground() -> some View {
        modifier(AppBackgroundModifier())
    }

    /// Centers page content on iPad while remaining edge-to-edge on iPhone.
    func pipCountPageContent(maxWidth: CGFloat? = nil) -> some View {
        modifier(PipCountPageContentModifier(requestedMaxWidth: maxWidth))
    }
}
