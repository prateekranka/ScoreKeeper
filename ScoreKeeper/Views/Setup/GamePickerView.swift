import SwiftUI

struct GamePickerView: View {
    @Environment(NavigationRouter.self) private var router
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
            .padding(.bottom, AppTheme.spacingXLarge)
            .pipCountPageContent()
        }
        .appBackground()
        .navigationTitle("")
        .toolbar(horizontalSizeClass == .regular ? .visible : .hidden, for: .navigationBar)
        .onAppear { contentVisible = true }
    }

    private var gridColumns: [GridItem] {
        if horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize {
            return [
                GridItem(.flexible(), spacing: AppTheme.spacingLarge, alignment: .top),
                GridItem(.flexible(), spacing: AppTheme.spacingLarge, alignment: .top)
            ]
        }

        return [GridItem(.flexible(), alignment: .top)]
    }


}

private struct GamePickerHero: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            Text("choose a game")
                .font(AppFonts.hero)
                .foregroundStyle(ClubhouseTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.62)

            Rectangle()
                .fill(ClubhouseTheme.blue)
                .frame(width: 82, height: 4)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 2)
    }
}
