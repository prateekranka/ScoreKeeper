import SwiftUI
import SwiftData

struct GameOverView: View {
    let sessionID: PersistentIdentifier
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext
    @Environment(NavigationRouter.self) private var router
    @Environment(StoreManager.self) private var storeManager
    @Environment(ReviewAskManager.self) private var reviewAskManager
    @Query(filter: #Predicate<GameSession> { $0.isComplete }) private var completedGames: [GameSession]
    @State private var sectionsVisible = false
    @State private var showPaywall = false
    @State private var didEvaluateReviewAsk = false
    @State private var saveError: String?

    var body: some View {
        SessionLoader(sessionID: sessionID) { session in
            let engine = GameEngineFactory.engine(for: session.gameType)
            let winnerIDs = engine.winners(session: session)
            let winners = session.players.filter { winnerIDs.contains($0.id) }

            ZStack {
                ScrollView {
                    VStack(spacing: AppTheme.spacingLarge) {
                        GameOverHeaderSection(
                            winners: winners,
                            sectionsVisible: sectionsVisible
                        )
                        .staggeredEntrance(visible: sectionsVisible, index: 0)

                        GameResultsCard(
                            session: session,
                            engine: engine,
                            winners: winners
                        )
                        .staggeredEntrance(visible: sectionsVisible, index: 1)

                        EndGameButtons(
                            session: session,
                            onPlayAgain: { playAgain(session) },
                            onHome: { router.goHome() }
                        )
                        .staggeredEntrance(visible: sectionsVisible, index: 2)
                    }
                    .padding(AppTheme.spacingMedium)
                }

                if !reduceMotion, !ProcessInfo.processInfo.arguments.contains("-in-memory-store") {
                    if sectionsVisible {
                        ConfettiOverlay()
                            .ignoresSafeArea()
                    }
                }
            }
            .appBackground()
            .onAppear {
                sectionsVisible = true
            }
            .sensoryFeedback(.success, trigger: sectionsVisible)
            .task(id: session.persistentModelID) {
                try? await Task.sleep(for: .milliseconds(750))
                evaluateReviewAskIfNeeded()
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(onUnlocked: { playAgain(session) })
                    .presentationDetents([.large])
            }
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .alert(
                "Couldn’t save rematch",
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
    }

    private func playAgain(_ session: GameSession) {
        guard storeManager.canStartNewGame else {
            showPaywall = true
            return
        }

        let newSession = GameSession(gameType: session.gameType)
        newSession.winCondition = session.winCondition
        newSession.targetScore = session.targetScore
        newSession.phase10SkipOnFail = session.phase10SkipOnFail
        modelContext.insert(newSession)

        for player in session.players {
            let newPlayer = Player(name: player.name, colorIndex: player.colorIndex)
            newPlayer.session = newSession
            newSession.players.append(newPlayer)
        }

        do {
            try modelContext.save()
        } catch {
            let message = error.localizedDescription
            modelContext.rollback()
            saveError = message
            return
        }
        storeManager.recordGameStarted()

        router.goHome()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            router.push(.scoring(newSession.persistentModelID))
        }
    }

    private func evaluateReviewAskIfNeeded() {
        guard !didEvaluateReviewAsk else { return }
        didEvaluateReviewAsk = true
        reviewAskManager.considerReviewAsk(
            completedGameCount: completedGames.count,
            paywallPresentedThisSession: storeManager.paywallPresentedThisSession
        )
    }
}

// MARK: - Subviews

private struct GameOverHeaderSection: View {
    let winners: [Player]
    let sectionsVisible: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: AppTheme.spacingMedium) {
            BauhausScreenHeader(
                title: "Game Over",
                subtitle: "Thanks for playing!",
                heroStyle: .gameOver
            )

            winnerAvatar
                .scaleEffect(sectionsVisible || reduceMotion ? 1 : 0.96)
                .opacity(sectionsVisible ? 1 : 0)
                .animation(reduceMotion ? AppMotion.fade : AppMotion.criticallyDamped.delay(0.06), value: sectionsVisible)
        }
        .padding(.top, AppTheme.spacingSmall)
    }

    @ViewBuilder
    private var winnerAvatar: some View {
        if winners.count == 1, let winner = winners.first {
            PlayerShapeIcon(colorIndex: winner.colorIndex, size: 72)
        } else if winners.count > 1 {
            HStack(spacing: AppTheme.spacingSmall) {
                ForEach(winners) { winner in
                    PlayerShapeIcon(colorIndex: winner.colorIndex, size: 52)
                }
            }
        } else {
            Image(systemName: "flag.checkered")
                .font(AppFonts.scoreDisplay)
                .foregroundStyle(ClubhouseTheme.bauhausBlue)
                .accessibilityHidden(true)
        }
    }
}

private struct GameResultsCard: View {
    let session: GameSession
    let engine: GameEngine
    let winners: [Player]

    private var standings: [PlayerStanding] {
        session.standings(using: engine)
    }

    private var featuredWinner: Player? {
        winners.first
    }

    var body: some View {
        VStack(spacing: AppTheme.spacingMedium) {
            Text("WINNER")
                .font(AppFonts.columnHeader.weight(.bold))
                .foregroundStyle(ClubhouseTheme.bauhausBlue)
                .tracking(1.2)

            winnerNameView

            Text("Great game!")
                .font(AppFonts.body)
                .foregroundStyle(ClubhouseTheme.inkMuted)

            if let winner = featuredWinner {
                Text("\(winner.totalScore(in: session))")
                    .font(AppFonts.scoreDisplay)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(winner.totalScore(in: session))))
                    .foregroundStyle(PlayerColors.color(for: winner.colorIndex))
            }

            VStack(spacing: 0) {
                ForEach(standings) { standing in
                    LedgerRow(
                        player: standing.player,
                        score: standing.score,
                        rank: standing.rank,
                        isLeader: standing.isWinner,
                        scoreColor: PlayerColors.color(for: standing.player.colorIndex)
                    )
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(standing.player.name), rank \(standing.rank), score \(standing.score)\(standing.isWinner ? ", winner" : "")")
                }
            }
            .padding(.top, AppTheme.spacingSmall)
        }
        .padding(AppTheme.spacingMedium)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var winnerNameView: some View {
        if winners.count == 1, let winner = winners.first {
            Text(winner.name)
                .font(AppFonts.largeTitle)
                .foregroundStyle(ClubhouseTheme.ink)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("winner_text")
        } else if winners.count > 1 {
            Text(winners.map(\.name).joined(separator: " & "))
                .font(AppFonts.largeTitle)
                .foregroundStyle(ClubhouseTheme.ink)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("winner_text")
        } else {
            Text("No winner")
                .font(AppFonts.largeTitle)
                .foregroundStyle(ClubhouseTheme.ink)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("winner_text")
        }
    }
}

private struct EndGameButtons: View {
    let session: GameSession
    let onPlayAgain: () -> Void
    let onHome: () -> Void

    var body: some View {
        VStack(spacing: AppTheme.spacingSmall) {
            BauhausPrimaryButton(
                title: "Play Again",
                systemImage: "arrow.counterclockwise",
                fill: session.gameType.color,
                action: onPlayAgain
            )
            .accessibilityIdentifier("play_again_button")

            Button(action: onHome) {
                HStack(spacing: 10) {
                    Image(systemName: "house")
                        .font(.body.weight(.semibold))
                    Text("Back Home")
                        .font(AppFonts.headline)
                }
                .foregroundStyle(ClubhouseTheme.ink)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(ClubhouseTheme.paperCard, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                        .strokeBorder(ClubhouseTheme.panelBorder, lineWidth: 1)
                }
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityIdentifier("home_button")
        }
    }
}
