import SwiftUI

extension Int {
    func quantityText(_ singular: String, plural: String? = nil) -> String {
        "\(self) \(self == 1 ? singular : plural ?? singular + "s")"
    }
}

enum AppButtonRole {
    case primary(Color)
    case secondary
    case destructive
}

struct AppSectionHeader: View {
    let title: String
    var subtitle: String?
    var systemImage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
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

struct ReleaseSheetHeader<Trailing: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var titleIdentifier: String?
    @ViewBuilder var trailing: Trailing
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 12))
        layout {
            Image(systemName: systemImage)
                .font(.headline.weight(.semibold))
                .foregroundStyle(ClubhouseTheme.blue)
                .frame(width: 42, height: 42)
                .background(ClubhouseTheme.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(ClubhouseTheme.blue.opacity(0.12), lineWidth: 1)
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                titleText

                Text(subtitle)
                    .font(AppFonts.caption)
                    .foregroundStyle(ClubhouseTheme.inkMuted)
            }

            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: AppTheme.spacingSmall) }
            trailing
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var titleText: some View {
        if let titleIdentifier {
            Text(title)
                .font(AppFonts.headline)
                .foregroundStyle(ClubhouseTheme.ink)
                .accessibilityIdentifier(titleIdentifier)
        } else {
            Text(title)
                .font(AppFonts.headline)
                .foregroundStyle(ClubhouseTheme.ink)
        }
    }
}

extension ReleaseSheetHeader where Trailing == EmptyView {
    init(title: String, subtitle: String, systemImage: String, titleIdentifier: String? = nil) {
        self.init(title: title, subtitle: subtitle, systemImage: systemImage, titleIdentifier: titleIdentifier) {
            EmptyView()
        }
    }
}

struct AppActionButton<LabelContent: View>: View {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let role: AppButtonRole
    let action: () -> Void
    @ViewBuilder var label: LabelContent

    var body: some View {
        Button(action: action) {
            label
                .font(dynamicTypeSize.isAccessibilitySize ? .body.weight(.bold) : AppFonts.headline)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.72)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 56)
                .padding(.horizontal, AppTheme.spacingMedium)
                .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 9 : 0)
                .foregroundStyle(foregroundStyle)
                .background {
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                        .fill(backgroundStyle)
                        .shadow(
                            color: role.isSecondary ? ClubhouseTheme.paperShadow.opacity(0.45) : ClubhouseTheme.paperShadow,
                            radius: role.isSecondary ? 8 : 12,
                            x: 0,
                            y: role.isSecondary ? 4 : 7
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                        .strokeBorder(strokeStyle, lineWidth: role.isSecondary ? 1 : 0.8)
                }
                .overlay(alignment: .top) {
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                        .trim(from: 0.53, to: 0.97)
                        .stroke(ClubhouseTheme.warmHighlight.opacity(role.isSecondary ? 0.45 : 0.34), lineWidth: 1)
                        .padding(1)
                }
        }
        .buttonStyle(PressableButtonStyle())

    }

    private var foregroundStyle: Color {
        guard isEnabled else { return ClubhouseTheme.inkMuted }
        return switch role {
        case .primary:
            ClubhouseTheme.onPrimary
        case .destructive:
            ClubhouseTheme.onFelt
        case .secondary:
            ClubhouseTheme.ink
        }
    }

    private var backgroundStyle: AnyShapeStyle {
        guard isEnabled else { return AnyShapeStyle(ClubhouseTheme.paperCard) }
        return switch role {
        case .primary(let color):
            AnyShapeStyle(
                LinearGradient(
                    colors: [color.opacity(0.98), color],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        case .secondary:
            AnyShapeStyle(ClubhouseTheme.paperCard)
        case .destructive:
            AnyShapeStyle(
                LinearGradient(
                    colors: [ClubhouseTheme.danger.opacity(0.92), ClubhouseTheme.danger],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

    private var strokeStyle: Color {
        switch role {
        case .secondary:
            ClubhouseTheme.panelBorder
        default:
            ClubhouseTheme.warmHighlight.opacity(0.26)
        }
    }
}

private extension AppButtonRole {
    var isSecondary: Bool {
        if case .secondary = self { return true }
        return false
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
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(ClubhouseTheme.paperCard, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(ClubhouseTheme.ruleStrong, lineWidth: 1)
                }
        } else if #available(iOS 26.0, *) {
            if isInteractive {
                content.glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
            } else {
                content.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
            }
        } else {
            content
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(ClubhouseTheme.warmHighlight.opacity(0.52), lineWidth: 1)
                }
        }
    }
}

// MARK: - Staggered Entrance

struct StaggeredEntranceModifier: ViewModifier {
    let visible: Bool
    let index: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible || reduceMotion ? 0 : 10)
            .scaleEffect(visible || reduceMotion ? 1 : 0.98)
            .blur(radius: visible || reduceMotion ? 0 : 2.5)
            .animation(
                reduceMotion
                    ? AppMotion.fade
                    : AppMotion.state.delay(min(Double(index) * 0.045, 0.22)),
                value: visible
            )
    }
}

// MARK: - Primary Navigation

enum PipCountTab: String, CaseIterable {
    case home
    case games
    case players
    case more

    var accessibilityIdentifier: String {
        self == .more ? "legal_support_button" : "tab_\(rawValue)"
    }

    var title: String {
        rawValue.capitalized
    }

    var systemImage: String {
        switch self {
        case .home: return "house"
        case .games: return "square.grid.2x2"
        case .players: return "person.2"
        case .more: return "ellipsis"
        }
    }

}
