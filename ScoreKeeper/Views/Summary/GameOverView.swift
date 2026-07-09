import SwiftUI
import SwiftData

struct GameOverView: View {
    let sessionID: PersistentIdentifier
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext
    @Environment(NavigationRouter.self) private var router
    @State private var sectionsVisible = false

    var body: some View {
        SessionLoader(sessionID: sessionID) { session in
            let engine = GameEngineFactory.engine(for: session.gameType)
            let winnerIDs = engine.winners(session: session)
            let winners = session.players.filter { winnerIDs.contains($0.id) }

            ZStack {
                ScrollView {
                    VStack(spacing: AppTheme.spacingLarge) {
                        WinnerHeroSection(session: session, winners: winners, sectionsVisible: sectionsVisible)
                            .staggeredEntrance(visible: sectionsVisible, index: 0)

                        VStack(spacing: AppTheme.spacingLarge) {
                            GameRecapPanel(session: session, engine: engine)
                            StandingsList(title: "Final Scores", standings: session.standings(using: engine))
                        }
                        .staggeredEntrance(visible: sectionsVisible, index: 1)

                        EndGameButtons(session: session, onPlayAgain: { playAgain(session) }, onHome: { router.goHome() })
                            .staggeredEntrance(visible: sectionsVisible, index: 2)
                    }
                    .padding(AppTheme.spacingMedium)
                }

                if !reduceMotion, !ProcessInfo.processInfo.arguments.contains("-in-memory-store") {
                    ConfettiOverlay()
                        .ignoresSafeArea()
                        .opacity(sectionsVisible ? 1 : 0)
                        .animation(.easeOut(duration: 0.6).delay(0.3), value: sectionsVisible)
                }
            }
            .appBackground()
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
                    sectionsVisible = true
                }
            }
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func playAgain(_ session: GameSession) {
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

        try? modelContext.save()

        router.goHome()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            router.push(.scoring(newSession.persistentModelID))
        }
    }
}

// MARK: - Subviews

private struct WinnerHeroSection: View {
    let session: GameSession
    let winners: [Player]
    let sectionsVisible: Bool

    var body: some View {
        VStack(spacing: AppTheme.spacingSmall) {
            Image(systemName: winners.isEmpty ? "flag.checkered" : "trophy.fill")
                .font(AppFonts.scoreDisplay)
                .foregroundStyle(winners.isEmpty ? session.gameType.color : ClubhouseTheme.brass)
                .accessibilityHidden(true)
                .scaleEffect(sectionsVisible ? 1 : 0.5)
                .animation(.spring(response: 0.6, dampingFraction: 0.5).delay(0.2), value: sectionsVisible)

            winnerText

            Text(session.gameType.displayName)
                .font(AppFonts.body)
                .foregroundStyle(ClubhouseTheme.inkMuted)

            StampBadge(text: "Winner")
        }
        .padding(.top, AppTheme.spacingXLarge)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var winnerText: some View {
        if winners.count == 1, let winner = winners.first {
            Text("\(winner.name) wins!")
                .font(AppFonts.largeTitle)
                .foregroundStyle(ClubhouseTheme.brass)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("winner_text")
        } else if winners.count > 1 {
            Text("\(winners.map(\.name).joined(separator: " & ")) win!")
                .font(AppFonts.largeTitle)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("winner_text")
        } else {
            Text("No winner")
                .font(AppFonts.largeTitle)
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
            AppActionButton(role: .primary(session.gameType.color), action: onPlayAgain) {
                Label("Play Again", systemImage: "arrow.counterclockwise")
            }
            .accessibilityIdentifier("play_again_button")

            AppActionButton(role: .secondary, action: onHome) {
                Text("Home")
            }
            .accessibilityIdentifier("home_button")
        }
    }
}

// MARK: - Recap

private struct GameRecapPanel: View {
    let session: GameSession
    let engine: GameEngine

    private var standings: [PlayerStanding] {
        session.standings(using: engine)
    }

    private var winningMargin: Int {
        guard standings.count > 1 else { return 0 }
        return abs(standings[0].score - standings[1].score)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
            AppSectionHeader(
                title: "Game Recap",
                subtitle: "A quick memory of how the table finished.",
                systemImage: "sparkles"
            )

            HStack(spacing: AppTheme.spacingSmall) {
                RecapMetric(title: "Rounds", value: "\(session.sortedRounds.count)", systemImage: "clock.arrow.circlepath", tint: session.gameType.color)
                RecapMetric(title: "Players", value: "\(session.players.count)", systemImage: "person.2.fill", tint: PlayerColors.palette[1])
                RecapMetric(title: "Margin", value: "\(winningMargin)", systemImage: "arrow.left.and.right", tint: PlayerColors.palette[0])
            }

            if !standings.isEmpty {
                ScoreSparkline(session: session, standings: standings)
                    .frame(height: 86)
                    .accessibilityLabel("Score trend")
            }
        }
        .padding(AppTheme.spacingMedium)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge)
    }
}

private struct RecapMetric: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .accessibilityHidden(true)

            Text(value)
                .font(AppFonts.scoreSmall)
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(Int(value) ?? 0)))
                .foregroundStyle(ClubhouseTheme.ink)

            Text(title)
                .font(AppFonts.caption)
                .foregroundStyle(ClubhouseTheme.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.spacingSmall)
        .background(ClubhouseTheme.paperSunken, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                .strokeBorder(ClubhouseTheme.rule, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Sparkline

private struct ScoreSparkline: View {
    let session: GameSession
    let standings: [PlayerStanding]

    var body: some View {
        GeometryReader { proxy in
            let series = chartSeries(in: proxy.size)

            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                    .fill(ClubhouseTheme.paperSunken)
                    .overlay {
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                            .strokeBorder(ClubhouseTheme.rule, lineWidth: 1)
                    }

                ForEach(series) { playerSeries in
                    Path { path in
                        guard let firstPoint = playerSeries.points.first else { return }
                        path.move(to: firstPoint)
                        for point in playerSeries.points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(playerSeries.color, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                }
            }
        }
    }

    private func chartSeries(in size: CGSize) -> [PlayerChartSeries] {
        let rounds = session.sortedRounds
        guard !rounds.isEmpty else { return [] }

        let cumulativeScores = session.players.map { player in
            var running = 0
            return rounds.map { round in
                running += round.entry(for: player.id)?.points ?? 0
                return running
            }
        }

        let allScores = cumulativeScores.flatMap { $0 }
        let minScore = allScores.min() ?? 0
        let maxScore = allScores.max() ?? 1
        let scoreRange = max(maxScore - minScore, 1)
        let usableWidth = max(size.width - 24, 1)
        let usableHeight = max(size.height - 20, 1)

        return session.players.enumerated().map { index, player in
            let values = cumulativeScores[index]
            let points = values.enumerated().map { valueIndex, value in
                let xProgress = rounds.count == 1 ? 0.5 : CGFloat(valueIndex) / CGFloat(rounds.count - 1)
                let yProgress = CGFloat(value - minScore) / CGFloat(scoreRange)
                return CGPoint(
                    x: 12 + xProgress * usableWidth,
                    y: 10 + (1 - yProgress) * usableHeight
                )
            }
            return PlayerChartSeries(
                id: player.id,
                color: PlayerColors.color(for: player.colorIndex),
                points: points
            )
        }
    }
}

private struct PlayerChartSeries: Identifiable {
    let id: UUID
    let color: Color
    let points: [CGPoint]
}
