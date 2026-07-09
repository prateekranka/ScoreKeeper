import SwiftUI
import SwiftData

struct GameConfigView: View {
    let gameType: GameType
    let playerNames: [String]

    @Environment(NavigationRouter.self) private var router
    @Environment(\.modelContext) private var modelContext

    @State private var winCondition: WinCondition = .highestScore
    @State private var phase10SkipOnFail = false

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacingLarge) {
                headerSection
                configSection
            }
            .padding(AppTheme.spacingMedium)
        }
        .appBackground()
        .navigationTitle("Game Settings")
        .safeAreaInset(edge: .bottom) {
            startButton
                .padding(.horizontal, AppTheme.spacingMedium)
                .padding(.vertical, AppTheme.spacingSmall)
                .background(.ultraThinMaterial)
        }
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
                .foregroundStyle(ClubhouseTheme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.spacingMedium)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge)
    }

    private var configSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
            if gameType == .generic {
                Text("How to win?")
                    .columnHeaderStyle()

                Picker("Win Condition", selection: $winCondition) {
                    Text("Highest Score Wins").tag(WinCondition.highestScore)
                    Text("Lowest Score Wins").tag(WinCondition.lowestScore)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("win_condition_picker")
            }

            if gameType == .phase10 {
                VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                    Toggle("No repeat rounds", isOn: $phase10SkipOnFail)
                        .font(AppFonts.body)
                        .tint(ClubhouseTheme.felt)

                    Text("Players advance to the next phase every round, even when they do not complete the current phase.")
                        .font(AppFonts.caption)
                        .foregroundStyle(ClubhouseTheme.inkMuted)
                }
            }
        }
        .padding(AppTheme.spacingMedium)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge)
    }

    private var startButton: some View {
        AppActionButton(role: .primary(gameType.color)) {
            let session = createSession()
            router.push(.scoring(session.persistentModelID))
        } label: {
            Label("Start Game", systemImage: "play.fill")
        }
        .accessibilityIdentifier("start_game_button")
    }

    private func createSession() -> GameSession {
        let session = GameSession(gameType: gameType)
        session.winCondition = winCondition
        session.phase10SkipOnFail = phase10SkipOnFail
        modelContext.insert(session)

        for (index, name) in playerNames.enumerated() {
            let player = Player(name: name, colorIndex: index)
            player.session = session
            session.players.append(player)
        }

        try? modelContext.save()
        savePlayersToRoster(names: playerNames)
        return session
    }

    private func savePlayersToRoster(names: [String]) {
        for name in names {
            let existing = try? modelContext.fetch(
                FetchDescriptor<SavedPlayer>(predicate: #Predicate { $0.name == name })
            ).first

            if let existing {
                existing.gamesPlayed += 1
                existing.lastUsed = .now
            } else {
                let saved = SavedPlayer(name: name, colorIndex: Int.random(in: 0..<PlayerColors.palette.count))
                saved.gamesPlayed = 1
                modelContext.insert(saved)
            }
        }
    }
}
