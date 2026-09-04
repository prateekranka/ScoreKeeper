import SwiftUI
import SwiftData

struct GameConfigView: View {
    let gameType: GameType
    let playerNames: [String]

    @Environment(NavigationRouter.self) private var router
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreManager.self) private var storeManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var winCondition: WinCondition = .highestScore
    @State private var phase10SkipOnFail = false
    @State private var targetScoreText = ""
    @State private var showPaywall = false
    @State private var saveError: String?
    @State private var contentVisible = false

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
                GameConfigHero(gameType: gameType)
                    .staggeredEntrance(visible: contentVisible, index: 0)

                responsiveConfiguration
            }
            .padding(.horizontal, AppTheme.spacingMedium)
            .padding(.top, AppTheme.spacingSmall)
            .padding(.bottom, 112)
            .pipCountPageContent(maxWidth: 980)
        }
        .appBackground()
        .navigationTitle("game settings")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            startButton
                .padding(.vertical, AppTheme.spacingSmall)
                .padding(.horizontal, AppTheme.spacingSmall)
                .appGlass(cornerRadius: AppTheme.cornerRadiusLarge, isInteractive: true)
                .padding(.horizontal, AppTheme.spacingMedium)
                .padding(.bottom, AppTheme.spacingSmall)
                .pipCountPageContent(maxWidth: AppTheme.formMaxWidth)
        }
        .onAppear {
            winCondition = gameType.defaultWinCondition
            contentVisible = true
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(onUnlocked: startConfiguredGame)
                .presentationDetents([.large])
        }
        .alert(
            "couldn’t save game",
            isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )
        ) {
            Button("ok", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "please try again")
        }
    }

    @ViewBuilder
    private var responsiveConfiguration: some View {
        if horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize {
            HStack(alignment: .top, spacing: AppTheme.spacingLarge) {
                configSection
                    .frame(maxWidth: .infinity)
                    .staggeredEntrance(visible: contentVisible, index: 1)

                lineupSection
                    .frame(width: 320)
                    .staggeredEntrance(visible: contentVisible, index: 2)
            }
        } else {
            VStack(spacing: AppTheme.spacingMedium) {
                configSection
                    .staggeredEntrance(visible: contentVisible, index: 1)
                lineupSection
                    .staggeredEntrance(visible: contentVisible, index: 2)
            }
        }
    }

    private var configSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingLarge) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("rules for tonight")
                        .font(AppFonts.title)
                        .foregroundStyle(ClubhouseTheme.ink)

                    Text("set this once. pipcount handles the rest")
                        .font(AppFonts.caption)
                        .foregroundStyle(ClubhouseTheme.inkMuted)
                }

                Spacer()

                Rectangle()
                    .fill(gameType.color)
                    .frame(width: 18, height: 18)
                    .rotationEffect(.degrees(45))
            }

            if gameType == .generic {
                VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                    Text("how to win?")
                        .columnHeaderStyle()

                    Picker("win condition", selection: $winCondition) {
                        Text("highest score wins").tag(WinCondition.highestScore)
                        Text("lowest score wins").tag(WinCondition.lowestScore)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("win_condition_picker")
                }

                Rectangle()
                    .fill(ClubhouseTheme.rule)
                    .frame(height: 1)

                targetScoreSection
            }

            if gameType == .phase10 {
                VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                    Toggle("no repeat rounds", isOn: $phase10SkipOnFail)
                        .font(AppFonts.body.weight(.semibold))
                        .tint(ClubhouseTheme.felt)

                    Text("players advance to the next stage every round, even when they do not complete the current stage")
                        .font(AppFonts.caption)
                        .foregroundStyle(ClubhouseTheme.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(AppTheme.spacingLarge)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge, isInteractive: true)
    }

    private var lineupSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
            VStack(alignment: .leading, spacing: 4) {
                Text("tonight's lineup")
                    .font(AppFonts.title)
                    .foregroundStyle(ClubhouseTheme.ink)

                Text(playerNames.count.quantityText("player"))
                    .font(AppFonts.caption)
                    .foregroundStyle(ClubhouseTheme.inkMuted)
            }

            VStack(spacing: 0) {
                ForEach(Array(playerNames.enumerated()), id: \.offset) { index, name in
                    HStack(spacing: AppTheme.spacingSmall) {
                        PlayerColorPip(colorIndex: index, size: 18)
                        Text(name)
                            .font(AppFonts.body.weight(.semibold))
                            .foregroundStyle(ClubhouseTheme.ink)
                            .lineLimit(1)
                        Spacer()
                        Text("\(index + 1)")
                            .columnHeaderStyle()
                            .monospacedDigit()
                    }
                    .padding(.vertical, 12)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(ClubhouseTheme.rule)
                            .frame(height: 1)
                    }
                }
            }

            HStack(spacing: 7) {
                Rectangle()
                    .fill(ClubhouseTheme.green)
                    .frame(width: 8, height: 8)
                    .rotationEffect(.degrees(45))

                Text("ready to score")
                    .font(AppFonts.caption.weight(.bold))
                    .foregroundStyle(ClubhouseTheme.green)
            }
        }
        .padding(AppTheme.spacingLarge)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge)
    }

    private var targetScoreSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            Text("target score (optional)")
                .font(AppFonts.body.weight(.semibold))
                .foregroundStyle(ClubhouseTheme.ink)

            TextField("manual end only", text: $targetScoreText)
                .font(AppFonts.body)
                .keyboardType(.numberPad)
                .textFieldStyle(.plain)
                .padding(.horizontal, AppTheme.spacingMedium)
                .frame(minHeight: 56)
                .background(ClubhouseTheme.paperSunken, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                        .strokeBorder(targetScoreError == nil ? ClubhouseTheme.rule : ClubhouseTheme.red, lineWidth: 1)
                }
                .accessibilityLabel("Target score, optional")
                .accessibilityHint("Leave blank to end the game manually")
                .accessibilityIdentifier("target_score_field")

            if let targetScoreError {
                Text(targetScoreError)
                    .font(AppFonts.caption.weight(.semibold))
                    .foregroundStyle(ClubhouseTheme.lacquer)
                    .accessibilityIdentifier("target_score_error")
            } else if let targetScore {
                Text(
                    winCondition == .highestScore
                        ? "the first player to reach \(targetScore) after a submitted round ends the game; highest total wins"
                        : "when any player reaches \(targetScore) after a submitted round, the game ends; lowest total wins"
                )
                .font(AppFonts.caption)
                .foregroundStyle(ClubhouseTheme.inkMuted)
            } else {
                Text("leave blank for manual-only completion")
                    .font(AppFonts.caption)
                    .foregroundStyle(ClubhouseTheme.inkMuted)
            }
        }
    }

    private var startButton: some View {
        AppActionButton(role: .primary(ClubhouseTheme.blue), action: startConfiguredGame) {
            Label("start game", systemImage: "arrow.right.circle.fill")
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

private struct GameConfigHero: View {
    let gameType: GameType

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize {
                HStack(alignment: .center, spacing: AppTheme.spacingXXLarge) {
                    copy
                        .frame(maxWidth: 390, alignment: .leading)

                    PipCountGeometricArtwork(scene: .gameSettings)
                        .frame(maxWidth: 500)
                        .frame(height: 290)
                }
            } else {
                HStack(alignment: .center, spacing: AppTheme.spacingMedium) {
                    copy
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if !dynamicTypeSize.isAccessibilitySize {
                        PipCountGeometricArtwork(scene: .gameSettings)
                            .frame(width: 168, height: 170)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var copy: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            Text(gameType.displayName)
                .font(AppFonts.hero)
                .foregroundStyle(ClubhouseTheme.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.78)

            Text("calibrate the rules for tonight")
                .font(AppFonts.body)
                .foregroundStyle(ClubhouseTheme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)

            Rectangle()
                .fill(gameType.color)
                .frame(width: 82, height: 4)
                .padding(.top, 4)
        }
    }
}
