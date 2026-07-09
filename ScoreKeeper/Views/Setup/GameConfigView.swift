import SwiftUI
import SwiftData

struct GameConfigView: View {
    let gameType: GameType
    let playerNames: [String]

    @Environment(NavigationRouter.self) private var router
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreAccessManager.self) private var storeAccess

    @State private var winCondition: WinCondition = .highestScore
    @State private var phase10SkipOnFail = false
    @State private var showPaywall = false
    @State private var continueAfterUnlock = false
    @State private var paywallUnlocked = false
    @State private var creationError: String?

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
        .sheet(isPresented: $showPaywall, onDismiss: handlePaywallDismissal) {
            PaywallView(
                onCancel: { continueAfterUnlock = false },
                onUnlock: { paywallUnlocked = true }
            )
        }
        .alert("Couldn’t Start Game", isPresented: creationErrorBinding) {
            Button("OK", role: .cancel) { creationError = nil }
        } message: {
            Text(creationError ?? "Please try again.")
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
                .accessibilityIdentifier("win_condition_picker")
            }

            if gameType == .phase10 {
                VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                    Toggle("No repeat rounds", isOn: $phase10SkipOnFail)
                        .font(AppFonts.body)

                    Text("Players advance to the next phase every round, even when they do not complete the current phase.")
                        .font(AppFonts.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(AppTheme.spacingMedium)
        .appCard(cornerRadius: AppTheme.cornerRadiusMedium)
    }

    private var startButton: some View {
        AppActionButton(role: .primary(gameType.color)) {
            startGame()
        } label: {
            Label("Start Game", systemImage: "play.fill")
        }
        .accessibilityIdentifier("start_game_button")
    }

    private var creationErrorBinding: Binding<Bool> {
        Binding(
            get: { creationError != nil },
            set: { if !$0 { creationError = nil } }
        )
    }

    private func startGame() {
        guard storeAccess.canStartNewGame else {
            continueAfterUnlock = true
            showPaywall = true
            return
        }

        guard let session = createSession() else { return }
        router.push(.scoring(session.persistentModelID))
    }

    private func handlePaywallDismissal() {
        let shouldContinue = paywallUnlocked && continueAfterUnlock
        paywallUnlocked = false
        continueAfterUnlock = false
        if shouldContinue {
            startGame()
        }
    }

    private func createSession() -> GameSession? {
        let session = GameSession(gameType: gameType)
        session.winCondition = winCondition
        session.phase10SkipOnFail = phase10SkipOnFail
        modelContext.insert(session)

        for (index, name) in playerNames.enumerated() {
            let player = Player(name: name, colorIndex: index)
            player.session = session
            session.players.append(player)
        }

        do {
            try modelContext.save()
            storeAccess.recordGameStarted()
            savePlayersToRoster(names: playerNames)
            return session
        } catch {
            modelContext.delete(session)
            creationError = "Your game couldn’t be saved. No free game was used."
            return nil
        }
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
