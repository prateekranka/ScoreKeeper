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
    #if DEBUG
    @ObservedObject private var tuning = PipTuning.shared
    #endif

    var body: some View {
        SessionLoader(sessionID: sessionID) { session in
            let engine = GameEngineFactory.engine(for: session.gameType)
            let winnerIDs = engine.winners(session: session)
            let winners = session.players.filter { winnerIDs.contains($0.id) }

            ZStack {
                ScrollView {
                    VStack(spacing: AppTheme.spacingLarge) {
                        BauhausScreenHeader(
                            title: "Game Over",
                            subtitle: "Thanks for playing!",
                            heroStyle: .gameOver,
                            artOffset: gameOverArtOffset,
                            artScale: gameOverArtScale
                        )
                        .staggeredEntrance(visible: sectionsVisible, index: 0)

                        GameResultsCard(
                            session: session,
                            engine: engine,
                            winners: winners,
                            sectionsVisible: sectionsVisible,
                            identityMarkSpacing: identityMarkSpacing
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
                    .padding(.bottom, 24)
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

    private var gameOverArtOffset: CGSize {
        #if DEBUG
        CGSize(width: tuning.gameOverArtOffsetX, height: tuning.gameOverArtOffsetY)
        #else
        .zero
        #endif
    }

    private var gameOverArtScale: CGFloat {
        #if DEBUG
        CGFloat(tuning.gameOverArtScale)
        #else
        1
        #endif
    }

    private var identityMarkSpacing: CGFloat {
        #if DEBUG
        CGFloat(tuning.identityMarkSpacing)
        #else
        24
        #endif
    }
}

// MARK: - Subviews

private struct GameResultsCard: View {
    let session: GameSession
    let engine: GameEngine
    let winners: [Player]
    let sectionsVisible: Bool
    var identityMarkSpacing: CGFloat = 24
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var standings: [PlayerStanding] {
        session.standings(using: engine)
    }

    private var tiedRanks: Set<Int> {
        Dictionary(grouping: standings, by: \.rank)
            .filter { $0.value.count > 1 }
            .reduce(into: Set<Int>()) { $0.insert($1.key) }
    }

    private var isTie: Bool {
        winners.count > 1
    }

    private var featuredWinner: Player? {
        winners.count == 1 ? winners.first : nil
    }

    private var winnerScore: Int? {
        winners.first.map { $0.totalScore(in: session) }
    }

    var body: some View {
        VStack(spacing: 0) {
            winnerHighlight
                .padding(AppTheme.spacingMedium)

            Rectangle()
                .fill(ClubhouseTheme.rule)
                .frame(height: 1)

            VStack(spacing: 0) {
                ForEach(Array(standings.enumerated()), id: \.element.id) { index, standing in
                    GameOverStandingRow(
                        standing: standing,
                        isTiedRank: tiedRanks.contains(standing.rank)
                    )
                        .opacity(sectionsVisible ? 1 : 0)
                        .offset(y: sectionsVisible || reduceMotion ? 0 : 6)
                        .animation(
                            reduceMotion
                                ? AppMotion.fade.delay(Double(index) * 0.03)
                                : AppMotion.entrance.delay(0.08 + Double(index) * 0.045),
                            value: sectionsVisible
                        )
                }
            }
            .padding(.horizontal, AppTheme.spacingSmall)
            .padding(.vertical, AppTheme.spacingSmall)
        }
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge)
        .accessibilityElement(children: .contain)
    }

    private var winnerHighlight: some View {
        HStack(alignment: .center, spacing: AppTheme.spacingMedium) {
            winnerMark
                .scaleEffect(sectionsVisible || reduceMotion ? 1 : 0.94)
                .opacity(sectionsVisible ? 1 : 0)
                .animation(reduceMotion ? AppMotion.fade : AppMotion.criticallyDamped.delay(0.04), value: sectionsVisible)

            VStack(alignment: .leading, spacing: 4) {
                Text(winners.isEmpty ? "RESULT" : isTie ? "TIE" : "WINNER")
                    .font(AppFonts.columnHeader.weight(.bold))
                    .foregroundStyle(ClubhouseTheme.bauhausBlue)
                    .tracking(1.2)

                winnerNameView

                Text(isTie ? "It’s a tie!" : session.gameType.displayName)
                    .font(AppFonts.caption)
                    .foregroundStyle(ClubhouseTheme.inkMuted)
            }

            Spacer(minLength: AppTheme.spacingSmall)

            if let winnerScore {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(winnerScore)")
                        .font(AppFonts.scoreDisplay)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(winnerScore)))
                        .foregroundStyle(isTie ? ClubhouseTheme.ink : PlayerColors.color(for: featuredWinner?.colorIndex ?? 0))
                    Text("points")
                        .font(AppFonts.caption)
                        .foregroundStyle(ClubhouseTheme.inkMuted)
                }
            }
        }
    }

    @ViewBuilder
    private var winnerMark: some View {
        if winners.count == 1, let winner = winners.first {
            ZStack {
                Circle()
                    .fill(PlayerColors.color(for: winner.colorIndex))
                    .frame(width: 64, height: 64)
                BauhausStar(color: ClubhouseTheme.onPrimary)
                    .frame(width: 26, height: 26)
            }
        } else if winners.count > 1 {
            HStack(spacing: identityMarkSpacing) {
                ForEach(winners.prefix(3)) { winner in
                    PlayerShapeIcon(colorIndex: winner.colorIndex, size: 44)
                        .overlay {
                            Circle()
                                .strokeBorder(ClubhouseTheme.paperCard, lineWidth: 2)
                        }
                }
            }
        } else {
            ZStack {
                Circle()
                    .fill(ClubhouseTheme.bauhausBlue)
                    .frame(width: 64, height: 64)
                Image(systemName: "flag.checkered")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(ClubhouseTheme.onPrimary)
            }
            .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var winnerNameView: some View {
        if winners.count == 1, let winner = winners.first {
            Text(winner.name)
                .font(AppFonts.largeTitle)
                .foregroundStyle(ClubhouseTheme.ink)
                .accessibilityIdentifier("winner_text")
        } else if winners.count > 1 {
            Text(winners.map(\.name).joined(separator: " & "))
                .font(AppFonts.title)
                .foregroundStyle(ClubhouseTheme.ink)
                .accessibilityIdentifier("winner_text")
        } else {
            Text("No winner")
                .font(AppFonts.largeTitle)
                .foregroundStyle(ClubhouseTheme.ink)
                .accessibilityIdentifier("winner_text")
        }
    }
}

private struct GameOverStandingRow: View {
    let standing: PlayerStanding
    var isTiedRank = false

    private var accent: Color {
        PlayerColors.color(for: standing.player.colorIndex)
    }

    private var rankText: String {
        isTiedRank ? "=\(standing.rank)" : "\(standing.rank)"
    }

    var body: some View {
        HStack(spacing: AppTheme.spacingSmall) {
            Text(rankText)
                .font(AppFonts.headline)
                .monospacedDigit()
                .foregroundStyle(ClubhouseTheme.inkMuted)
                .frame(width: 32, alignment: .leading)

            PlayerShapeIcon(colorIndex: standing.player.colorIndex, size: 24)

            Text(standing.player.name)
                .font(AppFonts.body.weight(.semibold))
                .foregroundStyle(ClubhouseTheme.ink)
                .lineLimit(1)

            Spacer(minLength: AppTheme.spacingSmall)

            if standing.isWinner {
                BrassCrown()
            }

            Text("\(standing.score)")
                .font(AppFonts.scoreSmall)
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(standing.score)))
                .foregroundStyle(accent)
                .frame(minWidth: 44, alignment: .trailing)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, AppTheme.spacingSmall)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(ClubhouseTheme.rule)
                .frame(height: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(standing.player.name), \(isTiedRank ? "tied for rank" : "rank") \(standing.rank), score \(standing.score)\(standing.isWinner ? ", winner" : "")"
        )
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
                systemImage: "arrow.right",
                fill: ClubhouseTheme.bauhausBlue,
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
                .shadow(color: ClubhouseTheme.paperShadow, radius: 6, y: 2)
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityIdentifier("home_button")
        }
    }
}
