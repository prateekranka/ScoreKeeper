import SwiftUI

struct GamePickerView: View {
    @Environment(NavigationRouter.self) private var router
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var contentVisible = false

    private let gameTypes: [GameType] = [.generic, .phase10, .whatsForDinner]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.spacingLarge) {
                GamePickerHero()
                    .staggeredEntrance(visible: contentVisible, index: 0)

                LazyVGrid(columns: gridColumns, spacing: AppTheme.spacingLarge) {
                    ForEach(Array(gameTypes.enumerated()), id: \.element.id) { index, gameType in
                        GameTypeTile(
                            gameType: gameType,
                            action: { router.push(.playerSetup(gameType)) },
                            accessibilityID: "game_tile_\(gameType.rawValue)"
                        )
                        .staggeredEntrance(visible: contentVisible, index: index + 1)
                    }
                }
            }
            .padding(.horizontal, AppTheme.spacingMedium)
            .padding(.top, AppTheme.spacingSmall)
            .padding(.bottom, 112)
            .pipCountPageContent()
        }
        .appBackground()
        .navigationTitle("")
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PipCountDock(selected: .games, onSelect: selectTab)
        }
        .onAppear { contentVisible = true }
    }

    private var gridColumns: [GridItem] {
        if horizontalSizeClass == .regular {
            return [
                GridItem(.flexible(), spacing: AppTheme.spacingLarge, alignment: .top),
                GridItem(.flexible(), spacing: AppTheme.spacingLarge, alignment: .top)
            ]
        }

        return [GridItem(.flexible(), alignment: .top)]
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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Group {
            if horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize {
                HStack(alignment: .center, spacing: AppTheme.spacingXXLarge) {
                    copy
                        .frame(maxWidth: 360, alignment: .leading)

                    PipCountGeometricArtwork(scene: .gamePicker)
                        .frame(maxWidth: 520)
                        .frame(height: AppTheme.regularHeroArtHeight)
                }
            } else {
                VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
                    copy

                    PipCountGeometricArtwork(scene: .gamePicker)
                        .frame(maxWidth: .infinity)
                        .frame(height: dynamicTypeSize.isAccessibilitySize ? 205 : AppTheme.heroArtHeight)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 2)
    }

    private var copy: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            Text("Choose\na Game")
                .font(AppFonts.hero)
                .foregroundStyle(ClubhouseTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("Pick your format for tonight.")
                .font(AppFonts.body)
                .foregroundStyle(ClubhouseTheme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)

            Rectangle()
                .fill(ClubhouseTheme.blue)
                .frame(width: 82, height: 4)
                .padding(.top, 4)
        }
    }
}
