import SwiftUI
import SwiftData

enum LegalSupportLinks {
    static let privacyPolicy = URL(string: "https://privacy.contenthelper.in")!
    static let support = URL(string: "https://support.contenthelper.in")!
}

struct LegalSupportView: View {
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
    @State private var showPaywall = false

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacingLarge) {
                responsiveContent
            }
            .padding(.horizontal, AppTheme.spacingMedium)
            .padding(.top, AppTheme.spacingSmall)
            .padding(.bottom, horizontalSizeClass == .regular ? AppTheme.spacingXLarge : 118)
            .pipCountPageContent(maxWidth: 1_080)
        }
        .appBackground()
        .navigationTitle("more")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PipCountDock(selected: .more, onSelect: selectTab)
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

    @ViewBuilder
    private var responsiveContent: some View {
        if horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize {
            HStack(alignment: .top, spacing: AppTheme.spacingLarge) {
                VStack(spacing: AppTheme.spacingMedium) {
                    proPanel
                        .staggeredEntrance(visible: contentVisible, index: 0)

                    recentGamesSection

                    appearancePanel
                        .staggeredEntrance(visible: contentVisible, index: 2)
                }
                .frame(maxWidth: 430, alignment: .top)

                supportPanel
                    .staggeredEntrance(visible: contentVisible, index: 3)
                    .frame(maxWidth: .infinity, alignment: .top)
            }
        } else {
            VStack(spacing: AppTheme.spacingMedium) {
                proPanel
                    .staggeredEntrance(visible: contentVisible, index: 0)

                recentGamesSection

                appearancePanel
                    .staggeredEntrance(visible: contentVisible, index: 2)

                supportPanel
                    .staggeredEntrance(visible: contentVisible, index: 3)
            }
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
            panelHeader(
                title: "appearance",
                systemImage: "circle.lefthalf.filled",
                compact: true
            )

            HStack(spacing: 5) {
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
                    .font(.subheadline.weight(.semibold))

                Text(title)
                    .font(AppFonts.caption.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .foregroundStyle(isSelected ? ClubhouseTheme.onPrimary : ClubhouseTheme.ink)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 36)
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
        Group {
            if storeManager.isUnlocked {
                HStack(spacing: AppTheme.spacingMedium) {
                    ZStack {
                        Circle()
                            .fill(ClubhouseTheme.yellow)
                            .frame(width: 68, height: 68)

                        BauhausStarburst(color: ClubhouseTheme.ink, size: 38)
                    }
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("pipcount pro")
                            .font(AppFonts.title)
                            .foregroundStyle(ClubhouseTheme.ink)

                        Text("unlimited game nights are unlocked on this apple id")
                            .font(AppFonts.body)
                            .foregroundStyle(ClubhouseTheme.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
                .padding(AppTheme.spacingMedium)
                .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("pro_unlocked_status")
            } else {
                Button {
                    showPaywall = true
                } label: {
                    HStack(spacing: AppTheme.spacingMedium) {
                        PipCountGeometricArtwork(scene: .paywall, ambientMotion: false)
                            .frame(width: 104, height: 96)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("pipcount pro")
                                .font(AppFonts.title)
                                .foregroundStyle(ClubhouseTheme.ink)

                            Text("\(storeManager.remainingFreeGames.quantityText("free game")) remaining")
                                .font(AppFonts.caption)
                                .foregroundStyle(ClubhouseTheme.inkMuted)
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)

                            Text("unlock unlimited games forever")
                                .font(AppFonts.caption.weight(.bold))
                                .foregroundStyle(ClubhouseTheme.blue)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }

                        Spacer(minLength: 0)

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(ClubhouseTheme.inkMuted)
                    }
                    .padding(AppTheme.spacingMedium)
                    .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge, isInteractive: true)
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel("Upgrade to PipCount Pro")
                .accessibilityIdentifier("more_upgrade_button")
            }
        }
    }

    private var supportPanel: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
            VStack(alignment: .leading, spacing: 0) {
                Link(destination: LegalSupportLinks.privacyPolicy) {
                    LegalSupportLink(
                        title: "privacy policy",
                        subtitle: "how pipcount handles your information",
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
                        subtitle: "get help or contact the pipcount team",
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
                .font(compact ? .footnote.weight(.semibold) : .headline.weight(.semibold))
                .foregroundStyle(ClubhouseTheme.blue)
                .frame(width: compact ? 30 : 42, height: compact ? 30 : 42)
                .background(ClubhouseTheme.blue.opacity(0.09), in: RoundedRectangle(cornerRadius: compact ? 9 : 14, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFonts.headline)
                    .foregroundStyle(ClubhouseTheme.ink)

                if let subtitle {
                    Text(subtitle)
                        .font(AppFonts.caption)
                        .foregroundStyle(ClubhouseTheme.inkMuted)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func selectTab(_ tab: PipCountTab) {
        switch tab {
        case .home:
            router.goHome()
        case .games:
            router.goHome()
            router.push(.gamePicker)
        case .players:
            router.goHome()
            router.push(.players)
        case .more:
            break
        }
    }
}

private struct LegalSupportLink: View {
    let title: String
    let subtitle: String
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

                Text(subtitle)
                    .font(AppFonts.caption)
                    .foregroundStyle(ClubhouseTheme.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: AppTheme.spacingSmall)

            Image(systemName: "arrow.up.right")
                .font(.caption.weight(.semibold))
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
