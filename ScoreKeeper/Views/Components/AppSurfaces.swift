import SwiftUI

enum AppButtonRole {
    case primary(Color)
    case secondary
    case destructive
}

struct AppSurface<Content: View>: View {
    var cornerRadius: CGFloat = AppTheme.cornerRadiusMedium
    var isInteractive = false
    @ViewBuilder var content: Content

    var body: some View {
        ScorecardSurface(cornerRadius: cornerRadius, isInteractive: isInteractive) {
            content
        }
    }
}

struct AppSectionHeader: View {
    let title: String
    var subtitle: String?
    var systemImage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let systemImage {
                Label(title, systemImage: systemImage)
                    .font(AppFonts.headline)
                    .foregroundStyle(ClubhouseTheme.ink)
            } else {
                Text(title)
                    .font(AppFonts.headline)
                    .foregroundStyle(ClubhouseTheme.ink)
            }

            if let subtitle {
                Text(subtitle)
                    .font(AppFonts.caption)
                    .foregroundStyle(ClubhouseTheme.inkMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AppActionButton<LabelContent: View>: View {
    let role: AppButtonRole
    let action: () -> Void
    @ViewBuilder var label: LabelContent
    @State private var trigger = 0

    var body: some View {
        Button {
            trigger &+= 1
            action()
        } label: {
            label
                .font(AppFonts.headline)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 50)
                .padding(.horizontal, AppTheme.spacingMedium)
                .foregroundStyle(foregroundStyle)
                .background(backgroundStyle, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                        .strokeBorder(strokeStyle, lineWidth: role.isSecondary ? 1 : 0)
                }
        }
        .buttonStyle(PressableButtonStyle())
        .sensoryFeedback(buttonHaptic, trigger: trigger)
    }

    private var buttonHaptic: SensoryFeedback {
        switch role {
        case .primary:
            return .impact(weight: .medium, intensity: 0.6)
        case .secondary:
            return .impact(weight: .light, intensity: 0.5)
        case .destructive:
            return .impact(weight: .heavy, intensity: 0.7)
        }
    }

    private var foregroundStyle: Color {
        switch role {
        case .primary, .destructive:
            ClubhouseTheme.onFelt
        case .secondary:
            ClubhouseTheme.ink
        }
    }

    private var backgroundStyle: AnyShapeStyle {
        switch role {
        case .primary:
            AnyShapeStyle(ClubhouseTheme.felt)
        case .secondary:
            AnyShapeStyle(ClubhouseTheme.paperCard)
        case .destructive:
            AnyShapeStyle(ClubhouseTheme.lacquer)
        }
    }

    private var strokeStyle: Color {
        role.isSecondary ? ClubhouseTheme.rule : .clear
    }
}

private extension AppButtonRole {
    var isSecondary: Bool {
        if case .secondary = self { return true }
        return false
    }
}

struct EmptyStateView: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        ContentUnavailableView(title, systemImage: systemImage, description: Text(message))
            .frame(maxWidth: .infinity, minHeight: 220)
    }
}

// MARK: - Glass + Material Modifier

extension View {
    func appGlass(cornerRadius: CGFloat, isInteractive: Bool = false) -> some View {
        modifier(AppGlassModifier(cornerRadius: cornerRadius, isInteractive: isInteractive))
    }

    func staggeredEntrance(visible: Bool, index: Int) -> some View {
        modifier(StaggeredEntranceModifier(visible: visible, index: index))
    }
}

@MainActor
@ViewBuilder
func glassGroup<Content: View>(spacing: CGFloat = 8, @ViewBuilder content: () -> Content) -> some View {
    if #available(iOS 26.0, *) {
        GlassEffectContainer(spacing: spacing) {
            content()
        }
    } else {
        content()
    }
}

struct AppGlassModifier: ViewModifier {
    let cornerRadius: CGFloat
    let isInteractive: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            if isInteractive {
                content.glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
            } else {
                content.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
            }
        } else {
            content.background(ClubhouseTheme.paperCard, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}

// MARK: - Staggered Entrance

struct StaggeredEntranceModifier: ViewModifier {
    let visible: Bool
    let index: Int

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 10)
            .animation(
                .spring(response: 0.45, dampingFraction: 0.78)
                    .delay(Double(index) * 0.06),
                value: visible
            )
    }
}
