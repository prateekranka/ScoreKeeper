import SwiftUI

struct GamePickerView: View {
    @Environment(NavigationRouter.self) private var router
    @State private var sectionsVisible = false

    private let columns = [
        GridItem(.flexible(), spacing: AppTheme.spacingSmall)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
                GamePickerHero()
                    .staggeredEntrance(visible: sectionsVisible, index: 0)

                LazyVGrid(columns: columns, spacing: AppTheme.spacingMedium) {
                    ForEach(Array(GameType.allCases.enumerated()), id: \.element.id) { index, gameType in
                        GameTypeTile(gameType: gameType, action: {
                            router.push(.playerSetup(gameType))
                        }, accessibilityID: "game_tile_\(gameType.rawValue)")
                        .staggeredEntrance(visible: sectionsVisible, index: index + 1)
                    }
                }
            }
            .padding(AppTheme.spacingMedium)
            .padding(.bottom, 76)
        }
        .appBackground()
        .navigationTitle("")
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PipCountDock(selected: .games, onSelect: selectTab)
        }
        .onAppear {
            sectionsVisible = true
        }
    }

    private func selectTab(_ tab: PipCountTab) {
        switch tab {
        case .home:
            router.goHome()
        case .games:
            break
        case .players:
            router.goHome()
            router.push(.players)
        case .more:
            router.push(.legalSupport)
        }
    }
}

private struct GamePickerHero: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: AppTheme.spacingMedium))
            : AnyLayout(HStackLayout(alignment: .bottom, spacing: AppTheme.spacingMedium))

        layout {
            VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                Text("Choose\na Game")
                    .font(AppFonts.hero)
                    .foregroundStyle(ClubhouseTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Pick your format for tonight.")
                    .font(AppFonts.body)
                    .foregroundStyle(ClubhouseTheme.inkMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !dynamicTypeSize.isAccessibilitySize {
                ZStack {
                    BauhausBlocksArtwork(compact: true)
                        .frame(width: 160, height: 138)
                    BauhausStarburst(color: ClubhouseTheme.red, size: 34)
                        .offset(x: 46, y: -48)
                }
                .frame(width: 160, height: 138)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, AppTheme.spacingSmall)
    }
}

private struct SetupFeature: Identifiable {
    let title: String
    let systemImage: String
    let tint: Color
    var id: String { title }
}

private struct SetupFeatureStrip: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let features = [
        SetupFeature(title: "Smart defaults", systemImage: "wand.and.stars", tint: PlayerColors.palette[2]),
        SetupFeature(title: "Saved crews", systemImage: "person.2.fill", tint: PlayerColors.palette[1]),
        SetupFeature(title: "Fast rematch", systemImage: "arrow.counterclockwise", tint: PlayerColors.palette[0])
    ]

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: AppTheme.spacingSmall))
            : AnyLayout(HStackLayout(spacing: AppTheme.spacingSmall))

        layout {
            ForEach(features) { feature in
                SetupFeatureChip(
                    title: feature.title,
                    systemImage: feature.systemImage,
                    tint: feature.tint
                )
            }
        }
    }
}

private struct SetupFeatureChip: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .accessibilityHidden(true)

            Text(title)
                .font(AppFonts.caption)
                .foregroundStyle(ClubhouseTheme.ink)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }
}

private struct SmartSetupPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            AppSectionHeader(
                title: "What gets set up",
                subtitle: "Each mode keeps only the choices that matter.",
                systemImage: "checklist"
            )

            FeatureRow(systemImage: "plus.forwardslash.minus", title: "Scoreboard", detail: "Highest or lowest score, target score, any game")
            FeatureRow(systemImage: "10.circle.fill", title: "Ten Phases", detail: "ten-stage card-game scoring")
            FeatureRow(systemImage: "fork.knife.circle.fill", title: "Dinner", detail: "Caller, card values, lowest total wins")
        }
        .padding(AppTheme.spacingMedium)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge)
    }
}

private struct FeatureRow: View {
    let systemImage: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: AppTheme.spacingSmall) {
            Image(systemName: systemImage)
                .foregroundStyle(PlayerColors.palette[3])
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFonts.body)
                    .foregroundStyle(ClubhouseTheme.ink)
                Text(detail)
                    .font(AppFonts.caption)
                    .foregroundStyle(ClubhouseTheme.inkMuted)
                    .lineLimit(2)
            }

            Spacer()
        }
    }
}
