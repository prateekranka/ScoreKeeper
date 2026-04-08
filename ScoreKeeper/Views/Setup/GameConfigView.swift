import SwiftUI
import SwiftData

struct GameConfigView: View {
    let gameType: GameType
    let playerNames: [String]

    @Environment(NavigationRouter.self) private var router
    @Environment(\.modelContext) private var modelContext

    @State private var winCondition: WinCondition = .highestScore

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacingLarge) {
                headerSection
                configSection
                startButton
            }
            .padding(AppTheme.spacingMedium)
        }
        .appBackground()
        .navigationTitle("Game Settings")
        .onAppear {
            winCondition = gameType.defaultWinCondition
        }
    }

    private var headerSection: some View {
        HStack(spacing: AppTheme.spacingSmall) {
            Image(systemName: gameType.icon)
                .font(.title2)
                .foregroundStyle(gameType.color)
            Text(gameType.displayName)
                .font(AppFonts.title)
        }
    }

    private var configSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
            if gameType == .generic {
                Text("How to win?")
                    .font(AppFonts.headline)

                Picker("Win Condition", selection: $winCondition) {
                    Text("Highest Score Wins").tag(WinCondition.highestScore)
                    Text("Lowest Score Wins").tag(WinCondition.lowestScore)
                }
                .pickerStyle(.segmented)
            }
        }
        .padding(AppTheme.spacingMedium)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
    }

    private var startButton: some View {
        Button {
            let session = createSession()
            router.push(.scoring(session.persistentModelID))
        } label: {
            Text("Start Game")
                .font(AppFonts.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppTheme.spacingMedium)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                        .fill(gameType.color)
                )
        }
        .buttonStyle(.plain)
        .padding(.top, AppTheme.spacingMedium)
    }

    private func createSession() -> GameSession {
        let session = GameSession(gameType: gameType)
        session.winCondition = winCondition
        modelContext.insert(session)

        for (index, name) in playerNames.enumerated() {
            let player = Player(name: name, colorIndex: index)
            player.session = session
            session.players.append(player)
        }

        try? modelContext.save()
        return session
    }
}
