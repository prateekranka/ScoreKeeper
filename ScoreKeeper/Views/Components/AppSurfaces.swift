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

    var body: some View {
        HStack(spacing: 12) {
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let role: AppButtonRole
    let action: () -> Void
    @ViewBuilder var label: LabelContent

    var body: some View {
        Button(action: action) {
            label
                .font(dynamicTypeSize.isAccessibilitySize ? .body.weight(.bold) : AppFonts.headline)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .minimumScaleFactor(0.72)
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
        .opacity(isEnabled ? 1 : 0.48)
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

    var title: String {
        rawValue.capitalized
    }

    var sidebarTitle: String {
        switch self {
        case .more: return "more"
        default: return title
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house"
        case .games: return "square.grid.2x2"
        case .players: return "person.2"
        case .more: return "ellipsis"
        }
    }

    var selectedSystemImage: String {
        switch self {
        case .home: return "house.fill"
        case .games: return "square.grid.2x2.fill"
        case .players: return "person.2.fill"
        case .more: return "ellipsis"
        }
    }
}

/// Compact-width primary navigation. On iPad the root split view supplies a
/// persistent sidebar instead, so the dock deliberately takes up no space.
struct PipCountDock: View {
    let selected: PipCountTab
    let onSelect: (PipCountTab) -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @ViewBuilder
    var body: some View {
        if horizontalSizeClass != .regular {
            dockContent
        }
    }

    private var dockContent: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [ClubhouseTheme.paper.opacity(0), ClubhouseTheme.paper.opacity(0.96)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 104)
            .allowsHitTesting(false)

            HStack(spacing: 4) {
                ForEach(PipCountTab.allCases, id: \.rawValue) { tab in
                    Button {
                        onSelect(tab)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: selected == tab ? tab.selectedSystemImage : tab.systemImage)
                                .font(.system(size: 17, weight: selected == tab ? .bold : .medium))
                            Text(tab.title)
                                .font(.caption2.weight(selected == tab ? .bold : .medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.65)
                        }
                        .foregroundStyle(selected == tab ? ClubhouseTheme.blue : ClubhouseTheme.inkMuted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background {
                            if selected == tab {
                                Capsule()
                                    .fill(ClubhouseTheme.blue.opacity(0.09))
                                    .padding(.horizontal, 2)
                            }
                        }
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
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(ClubhouseTheme.warmHighlight.opacity(0.72), lineWidth: 1.2)
            }
            .overlay {
                Capsule()
                    .inset(by: 1.5)
                    .strokeBorder(ClubhouseTheme.rule.opacity(0.72), lineWidth: 0.75)
            }
            .shadow(color: ClubhouseTheme.paperShadow, radius: 22, y: 10)
            .padding(.horizontal, 24)
            .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Persistent iPad navigation. The artwork and entitlement card use the same
/// visual grammar as the phone UI while leaving the detail column uncluttered.
struct PipCountSidebar: View {
    let selected: PipCountTab
    let onSelect: (PipCountTab) -> Void

    @Environment(StoreManager.self) private var storeManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var contentVisible = false
    @State private var showPaywall = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.spacingLarge) {
                    brand
                        .staggeredEntrance(visible: contentVisible, index: 0)

                    PipCountGeometricArtwork(scene: .homeEmpty)
                        .frame(maxWidth: .infinity)
                        .frame(height: 178)
                        .staggeredEntrance(visible: contentVisible, index: 1)

                    AppActionButton(role: .primary(ClubhouseTheme.blue)) {
                        onSelect(.games)
                    } label: {
                        Label("start new game", systemImage: "plus")
                    }
                    .accessibilityIdentifier("sidebar_new_game_button")
                    .staggeredEntrance(visible: contentVisible, index: 2)

                    navigationRows
                        .staggeredEntrance(visible: contentVisible, index: 3)
                }
                .padding(.horizontal, AppTheme.spacingMedium)
                .padding(.top, AppTheme.spacingLarge)
                .padding(.bottom, AppTheme.spacingLarge)
            }
            .scrollIndicators(.hidden)

            entitlementCard
                .padding(.horizontal, AppTheme.spacingMedium)
                .padding(.bottom, AppTheme.spacingMedium)
                .staggeredEntrance(visible: contentVisible, index: 4)
        }
        .background(PipCountPaperBackground().ignoresSafeArea())
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(ClubhouseTheme.rule)
                .frame(width: 1)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .presentationDetents([.large])
        }
        .onAppear {
            if reduceMotion {
                contentVisible = true
            } else {
                withAnimation(AppMotion.page) {
                    contentVisible = true
                }
            }
        }
    }

    private var brand: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("pipcount")
                    .font(AppFonts.largeTitle)
                    .foregroundStyle(ClubhouseTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                BauhausStarburst(color: ClubhouseTheme.blue, size: 21)
            }

            Text("game night, organized")
                .font(AppFonts.body)
                .foregroundStyle(ClubhouseTheme.inkMuted)

            Rectangle()
                .fill(ClubhouseTheme.red)
                .frame(width: 70, height: 4)
                .padding(.top, 3)
        }
    }

    private var navigationRows: some View {
        VStack(spacing: 6) {
            ForEach(PipCountTab.allCases, id: \.rawValue) { tab in
                Button {
                    onSelect(tab)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: selected == tab ? tab.selectedSystemImage : tab.systemImage)
                            .font(.system(size: 17, weight: selected == tab ? .bold : .semibold))
                            .frame(width: 24)

                        Text(tab.sidebarTitle)
                            .font(AppFonts.body.weight(selected == tab ? .bold : .semibold))

                        Spacer()

                        if selected == tab {
                            Rectangle()
                                .fill(ClubhouseTheme.green)
                                .frame(width: 9, height: 9)
                                .rotationEffect(.degrees(45))
                                .accessibilityHidden(true)
                        }
                    }
                    .foregroundStyle(selected == tab ? ClubhouseTheme.blue : ClubhouseTheme.ink)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 50)
                    .background {
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                            .fill(selected == tab ? ClubhouseTheme.blue.opacity(0.10) : Color.clear)
                    }
                    .overlay {
                        if selected == tab {
                            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                                .strokeBorder(ClubhouseTheme.blue.opacity(0.18), lineWidth: 1)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel(tab == .more ? "Legal & Support" : tab.title)
                .accessibilityIdentifier(tab == .more ? "sidebar_legal_support_button" : "sidebar_tab_\(tab.rawValue)")
                .accessibilityAddTraits(selected == tab ? .isSelected : [])
            }
        }
    }

    @ViewBuilder
    private var entitlementCard: some View {
        if storeManager.isUnlocked {
            HStack(spacing: AppTheme.spacingSmall) {
                ZStack {
                    Circle()
                        .fill(ClubhouseTheme.yellow)
                        .frame(width: 42, height: 42)
                    BauhausStarburst(color: ClubhouseTheme.ink, size: 24)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("pipcount pro")
                        .font(AppFonts.headline)
                        .foregroundStyle(ClubhouseTheme.ink)
                    Text("unlimited game nights")
                        .font(AppFonts.caption)
                        .foregroundStyle(ClubhouseTheme.inkMuted)
                }

                Spacer(minLength: 0)
            }
            .padding(AppTheme.spacingMedium)
            .scorecardSurface(cornerRadius: AppTheme.cornerRadiusMedium)
            .accessibilityElement(children: .combine)
        } else {
            Button {
                showPaywall = true
            } label: {
                HStack(spacing: AppTheme.spacingSmall) {
                    PipCountGeometricArtwork(scene: .paywall, ambientMotion: false)
                        .frame(width: 66, height: 62)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("pipcount pro")
                            .font(AppFonts.headline)
                            .foregroundStyle(ClubhouseTheme.ink)

                        Text("\(storeManager.remainingFreeGames.quantityText("free game")) left")
                            .font(AppFonts.caption)
                            .foregroundStyle(ClubhouseTheme.inkMuted)
                            .monospacedDigit()

                        Text("unlock forever")
                            .font(AppFonts.caption.weight(.bold))
                            .foregroundStyle(ClubhouseTheme.blue)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(ClubhouseTheme.inkMuted)
                }
                .padding(AppTheme.spacingSmall)
                .scorecardSurface(cornerRadius: AppTheme.cornerRadiusMedium, isInteractive: true)
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("Upgrade to PipCount Pro")
            .accessibilityIdentifier("sidebar_upgrade_button")
        }
    }
}
