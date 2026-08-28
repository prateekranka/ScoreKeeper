import SwiftUI

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

    @State private var contentVisible = false
    @State private var showPaywall = false

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacingLarge) {
                settingsHero
                    .staggeredEntrance(visible: contentVisible, index: 0)

                responsiveContent
            }
            .padding(.horizontal, AppTheme.spacingMedium)
            .padding(.top, AppTheme.spacingSmall)
            .padding(.bottom, horizontalSizeClass == .regular ? AppTheme.spacingXLarge : 118)
            .pipCountPageContent(maxWidth: 1_080)
        }
        .appBackground()
        .navigationTitle("More")
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
                    appearancePanel
                        .staggeredEntrance(visible: contentVisible, index: 1)

                    proPanel
                        .staggeredEntrance(visible: contentVisible, index: 2)
                }
                .frame(maxWidth: 430, alignment: .top)

                VStack(spacing: AppTheme.spacingMedium) {
                    supportPanel
                        .staggeredEntrance(visible: contentVisible, index: 3)

                    aboutPanel
                        .staggeredEntrance(visible: contentVisible, index: 4)
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
        } else {
            VStack(spacing: AppTheme.spacingMedium) {
                appearancePanel
                    .staggeredEntrance(visible: contentVisible, index: 1)

                proPanel
                    .staggeredEntrance(visible: contentVisible, index: 2)

                supportPanel
                    .staggeredEntrance(visible: contentVisible, index: 3)

                aboutPanel
                    .staggeredEntrance(visible: contentVisible, index: 4)
            }
        }
    }

    private var settingsHero: some View {
        Group {
            if horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize {
                HStack(alignment: .center, spacing: AppTheme.spacingXXLarge) {
                    heroCopy
                        .frame(maxWidth: 390, alignment: .leading)

                    PipCountGeometricArtwork(scene: .gameSettings)
                        .frame(maxWidth: 500)
                        .frame(height: 300)
                }
            } else {
                HStack(alignment: .center, spacing: AppTheme.spacingMedium) {
                    heroCopy
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if !dynamicTypeSize.isAccessibilitySize {
                        PipCountGeometricArtwork(scene: .gameSettings)
                            .frame(width: 168, height: 178)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var heroCopy: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            HStack(spacing: 8) {
                Text("PipCount")
                    .font(AppFonts.headline)
                    .foregroundStyle(ClubhouseTheme.ink)

                BauhausStarburst(color: ClubhouseTheme.blue, size: 18)
            }

            Text("Make it\nyours.")
                .font(AppFonts.hero)
                .foregroundStyle(ClubhouseTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("Appearance, PipCount Pro, privacy, and help — all in one place.")
                .font(AppFonts.body)
                .foregroundStyle(ClubhouseTheme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)

            Rectangle()
                .fill(ClubhouseTheme.red)
                .frame(width: 82, height: 4)
                .padding(.top, 4)
        }
    }

    private var appearancePanel: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
            panelHeader(
                title: "Appearance",
                subtitle: "Choose how PipCount looks on this device.",
                systemImage: "circle.lefthalf.filled"
            )

            HStack(spacing: AppTheme.spacingSmall) {
                appearanceButton(
                    mode: "system",
                    title: "System",
                    systemImage: "circle.lefthalf.filled"
                )

                appearanceButton(
                    mode: "light",
                    title: "Light",
                    systemImage: "sun.max.fill"
                )

                appearanceButton(
                    mode: "dark",
                    title: "Dark",
                    systemImage: "moon.fill"
                )
            }

            Text("System follows your iPhone or iPad appearance automatically.")
                .font(AppFonts.caption)
                .foregroundStyle(ClubhouseTheme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppTheme.spacingMedium)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge, isInteractive: true)
    }

    private func appearanceButton(mode: String, title: String, systemImage: String) -> some View {
        let isSelected = themeManager.mode == mode

        return Button {
            withAnimation(reduceMotion ? AppMotion.fade : AppMotion.theme) {
                themeManager.mode = mode
            }
        } label: {
            VStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))

                Text(title)
                    .font(AppFonts.caption.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .foregroundStyle(isSelected ? ClubhouseTheme.onPrimary : ClubhouseTheme.ink)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 72)
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
                        Text("PipCount Pro")
                            .font(AppFonts.title)
                            .foregroundStyle(ClubhouseTheme.ink)

                        Text("Unlimited game nights are unlocked on this Apple ID.")
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
                            Text("PipCount Pro")
                                .font(AppFonts.title)
                                .foregroundStyle(ClubhouseTheme.ink)

                            Text("\(storeManager.remainingFreeGames.quantityText("free game")) remaining")
                                .font(AppFonts.body)
                                .foregroundStyle(ClubhouseTheme.inkMuted)
                                .monospacedDigit()

                            Text("Unlock unlimited games forever")
                                .font(AppFonts.caption.weight(.bold))
                                .foregroundStyle(ClubhouseTheme.blue)
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
            panelHeader(
                title: "Privacy & Support",
                subtitle: "The details and help you need.",
                systemImage: "lifepreserver"
            )

            VStack(alignment: .leading, spacing: 0) {
                Link(destination: LegalSupportLinks.privacyPolicy) {
                    LegalSupportLink(
                        title: "Privacy Policy",
                        subtitle: "How PipCount handles your information",
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
                        title: "Support",
                        subtitle: "Get help or contact the PipCount team",
                        systemImage: "questionmark.bubble"
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("PipCount Support")
                .accessibilityHint("Open PipCount support")
                .accessibilityIdentifier("support_link")
            }

            Label("Links open in your default browser.", systemImage: "safari")
                .font(AppFonts.caption)
                .foregroundStyle(ClubhouseTheme.inkMuted)
                .accessibilityLabel("Privacy and support links open in your default browser.")
        }
        .padding(AppTheme.spacingMedium)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge)
    }

    private var aboutPanel: some View {
        HStack(alignment: .center, spacing: AppTheme.spacingMedium) {
            PipCountGeometricArtwork(scene: .homeEmpty, ambientMotion: false)
                .frame(width: 112, height: 104)

            VStack(alignment: .leading, spacing: 4) {
                Text("About PipCount")
                    .font(AppFonts.title)
                    .foregroundStyle(ClubhouseTheme.ink)

                Text("A private, local-first scorekeeper made for the people already around your table.")
                    .font(AppFonts.body)
                    .foregroundStyle(ClubhouseTheme.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)

                Text(versionText)
                    .columnHeaderStyle()
                    .foregroundStyle(ClubhouseTheme.blue)
                    .padding(.top, 3)
            }

            Spacer(minLength: 0)
        }
        .padding(AppTheme.spacingMedium)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge)
        .accessibilityElement(children: .combine)
    }

    private func panelHeader(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(spacing: AppTheme.spacingSmall) {
            Image(systemName: systemImage)
                .font(.headline.weight(.semibold))
                .foregroundStyle(ClubhouseTheme.blue)
                .frame(width: 42, height: 42)
                .background(ClubhouseTheme.blue.opacity(0.09), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFonts.headline)
                    .foregroundStyle(ClubhouseTheme.ink)

                Text(subtitle)
                    .font(AppFonts.caption)
                    .foregroundStyle(ClubhouseTheme.inkMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "VERSION \(version) • BUILD \(build)"
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
