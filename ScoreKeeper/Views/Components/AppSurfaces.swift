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

struct ReleaseSheetHeader<Trailing: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var titleIdentifier: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: AppTheme.spacingSmall) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(ClubhouseTheme.felt)
                .frame(width: 40, height: 40)
                .background(ClubhouseTheme.felt.opacity(0.10), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                titleText

                Text(subtitle)
                    .font(AppFonts.caption)
                    .foregroundStyle(ClubhouseTheme.inkMuted)
            }

            Spacer(minLength: AppTheme.spacingSmall)
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
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 52)
                .padding(.horizontal, AppTheme.spacingMedium)
                .foregroundStyle(foregroundStyle)
                .background(backgroundStyle, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                        .strokeBorder(strokeStyle, lineWidth: role.isSecondary ? 1.25 : 0)
                }
                .shadow(color: role.isSecondary ? .clear : ClubhouseTheme.ink.opacity(0.14), radius: 0, x: 2, y: 3)
        }
        .buttonStyle(PressableButtonStyle())
        .opacity(isEnabled ? 1 : 0.48)
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
        case .primary:
            ClubhouseTheme.onPrimary
        case .destructive:
            ClubhouseTheme.onFelt
        case .secondary:
            ClubhouseTheme.ink
        }
    }

    private var backgroundStyle: AnyShapeStyle {
        switch role {
        case .primary(let color):
            AnyShapeStyle(color)
        case .secondary:
            AnyShapeStyle(ClubhouseTheme.paperCard)
        case .destructive:
            AnyShapeStyle(ClubhouseTheme.danger)
        }
    }

    private var strokeStyle: Color {
        role.isSecondary ? ClubhouseTheme.panelBorder : .clear
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible || reduceMotion ? 0 : 10)
            .animation(
                reduceMotion
                    ? AppMotion.fade
                    : AppMotion.page.delay(min(Double(index) * 0.045, 0.24)),
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

struct PipCountDock: View {
    let selected: PipCountTab
    let onSelect: (PipCountTab) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(PipCountTab.allCases, id: \.rawValue) { tab in
                Button {
                    onSelect(tab)
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: selected == tab ? selectedImage(for: tab) : tab.systemImage)
                            .font(.system(size: 17, weight: selected == tab ? .bold : .medium))
                        Text(tab.title)
                            .font(.caption2.weight(selected == tab ? .bold : .medium))
                    }
                    .foregroundStyle(selected == tab ? ClubhouseTheme.blue : ClubhouseTheme.inkMuted)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel(tab == .more ? "Legal & Support" : tab.title)
                .accessibilityHint(tab == .more ? "Opens privacy, legal, and support links" : "")
                .accessibilityIdentifier(tab == .more ? "legal_support_button" : "tab_\(tab.rawValue)")
                .accessibilityAddTraits(selected == tab ? .isSelected : [])
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(ClubhouseTheme.paperCard.opacity(0.94), in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(ClubhouseTheme.ruleStrong, lineWidth: 1)
        }
        .shadow(color: ClubhouseTheme.ink.opacity(0.14), radius: 14, y: 7)
        .padding(.horizontal, AppTheme.spacingMedium)
        .padding(.bottom, 4)
    }

    private func selectedImage(for tab: PipCountTab) -> String {
        switch tab {
        case .home: return "house.fill"
        case .games: return "square.grid.2x2.fill"
        case .players: return "person.2.fill"
        case .more: return "ellipsis"
        }
    }
}
