import SwiftUI
import SwiftData

enum LegalSupportLinks {
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let privacyPolicy = URL(string: "https://privacy.contenthelper.in")!
    static let support = URL(string: "https://support.contenthelper.in")!
}

struct LegalSupportView: View {
    @Environment(\.pipCountUsesIsland) private var usesIsland
    @Environment(\.pipCountRailInset) private var railInset
    #if DEBUG
    @Environment(\.pipCountDebugFixtures) private var debugFixtures
    #endif
    @Environment(NavigationRouter.self) private var router
    @Environment(ThemeManager.self) private var themeManager
    @Environment(StoreManager.self) private var storeManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query(filter: #Predicate<GameSession> { $0.isComplete },
           sort: \GameSession.createdAt, order: .reverse)
    private var completedGames: [GameSession]

    @State private var contentVisible = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: railInset > 0 ? AppTheme.spacingMedium : AppTheme.spacingLarge) {
                if usesIsland {
                    VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
                        Text("more")
                            .font(AppFonts.hero)
                            .foregroundStyle(ClubhouseTheme.ink)
                        if railInset > 0 { proPanel }
                    }
                    .pipCountRailHeader()
                }
                #if DEBUG
                if let debugFixtures {
                    Menu {
                        ForEach(debugFixtures.modes, id: \.self) { mode in
                            Button(mode == "worst" ? "Worst case" : mode.capitalized) {
                                debugFixtures.select(mode)
                            }
                            .accessibilityIdentifier("break_ui_data_\(mode)")
                        }
                    } label: {
                        Text("Demo data / Worst case")
                            .font(AppFonts.label)
                            .padding(12)
                            .foregroundStyle(ClubhouseTheme.ink)
                            .background(ClubhouseTheme.paperCard, in: Capsule())
                    }
                    .accessibilityIdentifier("break_ui_data_toggle")
                }
                #endif
                responsiveContent
            }
            .padding(.horizontal, AppTheme.spacingMedium)
            .padding(.top, AppTheme.spacingSmall)
            .padding(.bottom, AppTheme.spacingXLarge)
            .pipCountPageContent(maxWidth: 1_080)
            .pipCountScrollContent()
        }
        .accessibilityIdentifier("more_content_scroll")
        .appBackground()
        .navigationTitle("more")
        .navigationBarTitleDisplayMode(.inline)
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

    @ViewBuilder
    private var responsiveContent: some View {
        if dynamicTypeSize.isAccessibilitySize {
            stackedContent
        } else {
            // Column count follows the space that is actually there: an iPad
            // with the sidebar open reports regular but leaves ~500 pt, which
            // squeezes the pro card into broken labels. PC-10 width contract.
            ViewThatFits(in: .horizontal) {
                sideBySideContent
                stackedContent
            }
        }
    }

    private var sideBySideContent: some View {
        HStack(alignment: .top, spacing: AppTheme.spacingLarge) {
            VStack(spacing: AppTheme.spacingMedium) {
                if railInset == 0 {
                    proPanel
                        .staggeredEntrance(visible: contentVisible, index: 0)
                }

                recentGamesSection

                appearancePanel
                    .staggeredEntrance(visible: contentVisible, index: 2)
            }
            .frame(minWidth: 430, maxWidth: 430, alignment: .top)

            supportPanel
                .staggeredEntrance(visible: contentVisible, index: 3)
                .frame(maxWidth: .infinity, alignment: .top)
        }
    }

    private var stackedContent: some View {
        VStack(spacing: AppTheme.spacingMedium) {
            if railInset == 0 {
                proPanel
                    .staggeredEntrance(visible: contentVisible, index: 0)
            }

            recentGamesSection

            appearancePanel
                .staggeredEntrance(visible: contentVisible, index: 2)

            supportPanel
                .staggeredEntrance(visible: contentVisible, index: 3)
        }
    }

    @ViewBuilder
    private var recentGamesSection: some View {
        if !completedGames.isEmpty {
            HomeRecentGamesSection(
                sessions: completedGames,
                onGameTap: { router.push(.gameDetail($0)) },
                onSeeAll: { router.push(.gameHistory) }
            )
            .staggeredEntrance(visible: contentVisible, index: 1)
        }
    }

    private var appearancePanel: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            if railInset == 0 || dynamicTypeSize.isAccessibilitySize {
                panelHeader(
                    title: "appearance",
                    systemImage: "circle.lefthalf.filled",
                    compact: true
                )
            }

            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: AppTheme.spacingSmall))
                : AnyLayout(HStackLayout(spacing: 5))
            layout {
                appearanceButton(
                    mode: "system",
                    title: "system",
                    systemImage: "circle.lefthalf.filled"
                )

                appearanceButton(
                    mode: "light",
                    title: "light",
                    systemImage: "sun.max.fill"
                )

                appearanceButton(
                    mode: "dark",
                    title: "dark",
                    systemImage: "moon.fill"
                )
            }
        }
        .padding(8)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge, isInteractive: true)
    }

    private func appearanceButton(mode: String, title: String, systemImage: String) -> some View {
        let isSelected = themeManager.mode == mode

        return Button {
            withAnimation(reduceMotion ? AppMotion.fade : AppMotion.theme) {
                themeManager.mode = mode
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))

                Text(title)
                    .font(AppFonts.label.weight(.bold))
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(isSelected ? ClubhouseTheme.onPrimary : ClubhouseTheme.ink)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .background {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                    .fill(isSelected ? ClubhouseTheme.blue : ClubhouseTheme.paperSunken)
            }
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                    .strokeBorder(
                        isSelected ? ClubhouseTheme.blue : ClubhouseTheme.rule,
                        lineWidth: isSelected ? 1.5 : 1
                    )
            }
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("\(title) appearance")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("theme_\(mode)_button")
    }

    private var proPanel: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            Button {
                if storeManager.isPro {
                    AppEntryPoint.shared.open(.proManagement)
                } else {
                    storeManager.presentPaywall()
                }
            } label: {
                Label("PipCount Pro", systemImage: storeManager.isPro ? "checkmark.seal" : "infinity")
                    .font(AppFonts.title)
                    .foregroundStyle(storeManager.isPro ? ClubhouseTheme.ink : ClubhouseTheme.brass)
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                    .padding(AppTheme.spacingMedium)
                    .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge, isInteractive: true)
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityIdentifier(storeManager.isPro ? "pro_unlocked_status" : "more_upgrade_button")
            if storeManager.shouldShowFreeGamesSignal {
                Text("\(storeManager.remainingFreeGames.quantityText("free game")) left")
                    .font(.subheadline)
                    .foregroundStyle(ClubhouseTheme.ink)
            }
        }
    }

    private var supportPanel: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
            VStack(alignment: .leading, spacing: 0) {
                Link(destination: LegalSupportLinks.privacyPolicy) {
                    LegalSupportLink(
                        title: "privacy policy",
                        systemImage: "hand.raised"
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("PipCount Privacy Policy")
                .accessibilityHint("Open PipCount's privacy policy")
                .accessibilityIdentifier("privacy_policy_link")

                Divider()
                    .overlay(ClubhouseTheme.rule)

                Link(destination: LegalSupportLinks.support) {
                    LegalSupportLink(
                        title: "support",
                        systemImage: "questionmark.bubble"
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("PipCount Support")
                .accessibilityHint("Open PipCount support")
                .accessibilityIdentifier("support_link")
            }
        }
        .padding(AppTheme.spacingMedium)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge)
    }

    private func panelHeader(title: String, subtitle: String? = nil, systemImage: String, compact: Bool = false) -> some View {
        HStack(spacing: compact ? 6 : AppTheme.spacingSmall) {
            Image(systemName: systemImage)
                .font(compact ? .body.weight(.semibold) : .headline.weight(.semibold))
                .foregroundStyle(ClubhouseTheme.blue)
                .frame(width: compact ? 30 : 42, height: compact ? 30 : 42)
                .background(ClubhouseTheme.blue.opacity(0.09), in: RoundedRectangle(cornerRadius: compact ? 9 : 14, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFonts.headline)
                    .foregroundStyle(ClubhouseTheme.ink)

                if let subtitle {

                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

}

private struct LegalSupportLink: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: AppTheme.spacingSmall) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(ClubhouseTheme.blue)
                .frame(width: 34)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFonts.headline)
                    .foregroundStyle(ClubhouseTheme.ink)

            }

            Spacer(minLength: AppTheme.spacingSmall)

            Image(systemName: "arrow.up.right")
                .font(.body.weight(.semibold))
                .foregroundStyle(ClubhouseTheme.inkMuted)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack {
        LegalSupportView()
    }
}
