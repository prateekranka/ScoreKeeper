import SwiftUI

struct GamePickerView: View {
    @Environment(NavigationRouter.self) private var router

    private let columns = [
        GridItem(.flexible(), spacing: AppTheme.spacingMedium),
        GridItem(.flexible(), spacing: AppTheme.spacingMedium)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: AppTheme.spacingMedium) {
                ForEach(GameType.allCases) { gameType in
                    GameTypeTile(gameType: gameType) {
                        router.push(.playerSetup(gameType))
                    }
                }
            }
            .padding(AppTheme.spacingMedium)
        }
        .appBackground()
        .navigationTitle("Choose a Game")
    }
}
