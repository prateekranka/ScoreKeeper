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
                    .font(AppFonts.label)
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
                    .font(AppFonts.label)
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
        case .primary(let color):
            ClubhouseTheme.onButton(color)
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
            AnyShapeStyle(color)
        case .secondary:
            AnyShapeStyle(ClubhouseTheme.paperCard)
        case .destructive:
            AnyShapeStyle(ClubhouseTheme.danger)
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

private struct PipCountUsesIslandKey: EnvironmentKey {
    static let defaultValue = false
}

private struct PipCountRailInsetKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

private struct PipCountIslandClearanceKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

#if DEBUG
struct PipCountDebugFixtures: Sendable {
    let modes: [String]
    let select: @MainActor @Sendable (String) -> Void
}

private struct PipCountDebugFixturesKey: EnvironmentKey {
    static let defaultValue: PipCountDebugFixtures? = nil
}
#endif

extension EnvironmentValues {
    var pipCountUsesIsland: Bool {
        get { self[PipCountUsesIslandKey.self] }
        set { self[PipCountUsesIslandKey.self] = newValue }
    }

    var pipCountRailInset: CGFloat {
        get { self[PipCountRailInsetKey.self] }
        set { self[PipCountRailInsetKey.self] = newValue }
    }

    var pipCountIslandClearance: CGFloat {
        get { self[PipCountIslandClearanceKey.self] }
        set { self[PipCountIslandClearanceKey.self] = newValue }
    }

    #if DEBUG
    var pipCountDebugFixtures: PipCountDebugFixtures? {
        get { self[PipCountDebugFixturesKey.self] }
        set { self[PipCountDebugFixturesKey.self] = newValue }
    }
    #endif

}

struct PipCountIsland<Content: View>: View {
    @Environment(\.pipCountRailInset) private var railInset
    @ViewBuilder var content: Content

    var body: some View {
        glassGroup {
            HStack(spacing: 6) {
                content
            }
            .padding(6)
            .appGlass(cornerRadius: 100, isInteractive: true)
            .fixedSize()
        }
        .fixedSize()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("navigation_island")
    }
}

struct PipCountIslandButton: View {
    let title: String
    let systemImage: String
    let identifier: String
    var isSelected = false
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            PipCountIslandLabel(title: title, systemImage: systemImage, isSelected: isSelected && isEnabled)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityIdentifier(identifier)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct PipCountIslandLabel: View {
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 20
    let title: String
    let systemImage: String
    var isSelected = false

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: min(iconSize, 28), weight: .semibold))
            .frame(width: 48, height: 48)
            .padding(4)
            .foregroundStyle(isSelected ? ClubhouseTheme.onPrimary : ClubhouseTheme.ink)
            .background(isSelected ? ClubhouseTheme.blue : ClubhouseTheme.paperCard, in: Capsule())
            .accessibilityLabel(title)
    }
}

struct PipCountBackButton: View {
    @Environment(NavigationRouter.self) private var router

    var body: some View {
        PipCountIslandButton(title: "Back", systemImage: "chevron.left", identifier: "island_back_button") {
            router.pop()
        }
    }
}

private struct PipCountIslandOverlay<Actions: View>: ViewModifier {
    @Environment(\.pipCountUsesIsland) private var usesIsland
    @Environment(\.pipCountRailInset) private var railInset
    @State private var islandHeight: CGFloat = 0
    var isPresented: Bool
    @ViewBuilder var actions: Actions

    func body(content: Content) -> some View {
        let isVisible = usesIsland && isPresented
        content
            .environment(\.pipCountIslandClearance, isVisible ? islandHeight + 16 : 0)
            .ignoresSafeArea(.container, edges: railInset > 0 ? .trailing : [])
            .overlay(alignment: .bottomTrailing) {
                if isVisible {
                    PipCountIsland { actions }
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { islandHeight = $0 }
                        .padding(.trailing, AppTheme.spacingMedium)
                        .padding(.bottom, 8)
                        .ignoresSafeArea(.container, edges: railInset > 0 ? .trailing : [])
                }
            }
            .background {
                if usesIsland { ClubhouseTheme.paper.ignoresSafeArea() }
            }
    }
}

private struct PipCountRailHeader: ViewModifier {
    @Environment(\.pipCountRailInset) private var railInset

    func body(content: Content) -> some View {
        content
            .padding(.trailing, railInset)
            .frame(minHeight: railInset * 2, alignment: .topLeading)
    }
}

private struct PipCountScrollContent: ViewModifier {
    @Environment(\.pipCountIslandClearance) private var clearance

    func body(content: Content) -> some View {
        content.padding(.bottom, clearance)
    }
}

extension View {
    func pipCountIsland<Actions: View>(isPresented: Bool = true, @ViewBuilder actions: () -> Actions) -> some View {
        modifier(PipCountIslandOverlay(isPresented: isPresented, actions: actions))
    }

    func pipCountRailHeader() -> some View {
        modifier(PipCountRailHeader())
    }

    func pipCountScrollContent() -> some View {
        modifier(PipCountScrollContent())
    }
}
