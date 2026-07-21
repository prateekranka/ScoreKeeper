import SwiftUI
import SwiftData

struct GameConfigView: View {
    let gameType: GameType
    let playerNames: [String]

    @Environment(NavigationRouter.self) private var router
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreManager.self) private var storeManager

    @State private var winCondition: WinCondition = .highestScore
    @State private var phase10SkipOnFail = false
    @State private var targetScoreText = ""
    @State private var showPaywall = false
    @State private var saveError: String?

    private var targetScoreError: String? {
        guard gameType == .generic else { return nil }
        return TargetScoreConfiguration.validationMessage(for: targetScoreText)
    }

    private var targetScore: Int? {
        TargetScoreConfiguration.value(from: targetScoreText)
    }

    private var canStart: Bool {
        targetScoreError == nil
    }

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
                .padding(.vertical, AppTheme.spacingSmall)
                .padding(.horizontal, AppTheme.spacingSmall)
                .appGlass(cornerRadius: AppTheme.cornerRadiusLarge, isInteractive: true)
                .padding(.horizontal, AppTheme.spacingMedium)
                .padding(.bottom, AppTheme.spacingSmall)
        }
        .onAppear {
            winCondition = gameType.defaultWinCondition
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(onUnlocked: startConfiguredGame)
                .presentationDetents([.large])
        }
        .alert(
            "Couldn’t save game",
            isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "Please try again.")
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

                targetScoreSection
            }

            if gameType == .phase10 {
                VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                    Toggle("No repeat rounds", isOn: $phase10SkipOnFail)
                        .font(AppFonts.body)
                        .tint(ClubhouseTheme.felt)

                    Text("Players advance to the next stage every round, even when they do not complete the current stage.")
                        .font(AppFonts.caption)
                        .foregroundStyle(ClubhouseTheme.inkMuted)
                }
            }
        }
        .padding(AppTheme.spacingMedium)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge)
    }

    private var targetScoreSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            Text("Target score (optional)")
                .font(AppFonts.body)
                .foregroundStyle(ClubhouseTheme.ink)

            TextField("Manual end only", text: $targetScoreText)
                .font(AppFonts.body)
                .keyboardType(.numberPad)
                .textFieldStyle(.plain)
                .padding(.vertical, AppTheme.spacingSmall)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(ClubhouseTheme.ruleStrong)
                        .frame(height: 1)
                }
                .accessibilityLabel("Target score, optional")
                .accessibilityHint("Leave blank to end the game manually")
                .accessibilityIdentifier("target_score_field")

            if let targetScoreError {
                Text(targetScoreError)
                    .font(AppFonts.caption)
                    .foregroundStyle(ClubhouseTheme.lacquer)
                    .accessibilityIdentifier("target_score_error")
            } else if let targetScore {
                Text(winCondition == .highestScore
                     ? "The first player to reach \(targetScore) after a submitted round ends the game; highest total wins."
                     : "When any player reaches \(targetScore) after a submitted round, the game ends; lowest total wins.")
                .font(AppFonts.caption)
                .foregroundStyle(ClubhouseTheme.inkMuted)
            } else {
                Text("Leave blank for manual-only completion.")
                    .font(AppFonts.caption)
                    .foregroundStyle(ClubhouseTheme.inkMuted)
            }
        }
        .padding(.top, AppTheme.spacingSmall)
    }

    private var startButton: some View {
        AppActionButton(role: .primary(ClubhouseTheme.blue), action: startConfiguredGame) {
            Label("Start Game", systemImage: "arrow.right.circle.fill")
        }
        .accessibilityIdentifier("start_game_button")
        .disabled(!canStart)
    }

    private func startConfiguredGame() {
        guard storeManager.canStartNewGame else {
            showPaywall = true
            return
        }

        guard let session = createSession() else { return }
        storeManager.recordGameStarted()
        router.push(.scoring(session.persistentModelID))
    }

    private func createSession() -> GameSession? {
        let session = GameSession(gameType: gameType)
        session.winCondition = winCondition
        session.targetScore = gameType == .generic ? targetScore : nil
        session.phase10SkipOnFail = phase10SkipOnFail
        modelContext.insert(session)

        for (index, name) in playerNames.enumerated() {
            let player = Player(name: name, colorIndex: index)
            player.session = session
            session.players.append(player)
        }

        do {
            try savePlayersToRoster(names: playerNames)
            try modelContext.save()
            return session
        } catch {
            let message = error.localizedDescription
            modelContext.rollback()
            saveError = message
            return nil
        }
    }

    private func savePlayersToRoster(names: [String]) throws {
        for name in names {
            let existing = try modelContext.fetch(
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
