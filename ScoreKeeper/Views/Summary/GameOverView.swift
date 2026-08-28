import SwiftData
import SwiftUI

struct GameOverView: View {
    let sessionID: PersistentIdentifier

    @Environment(NavigationRouter.self) private var router
    @Environment(StoreManager.self) private var storeManager
    @Environment(ReviewAskManager.self) private var reviewAskManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<GameSession> { $0.isComplete })
    private var completedGames: [GameSession]

    @State private var contentVisible = false
    @State private var showPaywall = false
    @State private var didEvaluateReviewAsk = false
    @State private var saveError: String?

    var body: some View {
        SessionLoader(sessionID: sessionID) { session in
            gameOverContent(session)
                .sheet(isPresented: $showPaywall) {
                    PaywallView(onUnlocked: { playAgain(session) })
                        .presentationDetents([.large])
                }
                .task(id: session.persistentModelID) {
                    try? await Task.sleep(for: .milliseconds(750))
                    evaluateReviewAskIfNeeded()
                }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            contentVisible = true
        }
        .sensoryFeedback(.success, trigger: contentVisible)
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

    @ViewBuilder
    private func gameOverContent(_ session: GameSession) -> some View {
        GeometryReader { proxy in
            ScrollView {
                if proxy.size.width >= 820 {
                    tabletLayout(session, availableWidth: proxy.size.width)
                } else {
                    phoneLayout(session)
                }
            }
            .scrollIndicators(.hidden)
        }
        .appBackground()
    }

    private func phoneLayout(_ session: GameSession) -> some View {
        VStack(spacing: AppTheme.spacingMedium) {
            completionHeader(session)
                .staggeredEntrance(visible: contentVisible, index: 0)

            resultHero(session)
                .staggeredEntrance(visible: contentVisible, index: 1)

            standingsCard(session)
                .staggeredEntrance(visible: contentVisible, index: 2)

            actionStack(session)
                .staggeredEntrance(visible: contentVisible, index: 3)

            recapGrid(session)
                .staggeredEntrance(visible: contentVisible, index: 4)

            shareButton(session)
                .staggeredEntrance(visible: contentVisible, index: 5)
        }
        .padding(.horizontal, AppTheme.spacingMedium)
        .padding(.top, AppTheme.spacingSmall)
        .padding(.bottom, AppTheme.spacingLarge)
        .responsiveContentWidth()
    }

    private func tabletLayout(_ session: GameSession, availableWidth: CGFloat) -> some View {
        VStack(spacing: AppTheme.spacingLarge) {
            HStack(alignment: .top, spacing: AppTheme.spacingXLarge) {
                VStack(alignment: .leading, spacing: AppTheme.spacingLarge) {
                    completionHeader(session)
                        .staggeredEntrance(visible: contentVisible, index: 0)

                    resultHero(session)
                        .staggeredEntrance(visible: contentVisible, index: 1)

                    actionStack(session)
                        .staggeredEntrance(visible: contentVisible, index: 3)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)

                VStack(spacing: AppTheme.spacingMedium) {
                    standingsCard(session)
                        .staggeredEntrance(visible: contentVisible, index: 2)

                    recapGrid(session)
                        .staggeredEntrance(visible: contentVisible, index: 4)

                    shareButton(session)
                        .staggeredEntrance(visible: contentVisible, index: 5)
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
        .padding(AppTheme.spacingXLarge)
        .frame(maxWidth: min(availableWidth, 1180), alignment: .top)
        .frame(maxWidth: .infinity)
    }

    private func completionHeader(_ session: GameSession) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            HStack(alignment: .top, spacing: AppTheme.spacingMedium) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Game\nOver")
                        .font(AppFonts.display)
                        .foregroundStyle(ClubhouseTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(session.gameType.displayName)
                        .font(AppFonts.body.weight(.semibold))
                        .foregroundStyle(ClubhouseTheme.blue)

                    Text("The scores are saved. The rematch is one tap away.")
                        .font(AppFonts.body)
                        .foregroundStyle(ClubhouseTheme.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: AppTheme.spacingSmall)

                PipCountGeometricArtwork(scene: .gameOver)
                    .frame(minWidth: 160, idealWidth: 220, maxWidth: 260)
                    .frame(height: 210)
            }

            Rectangle()
                .fill(ClubhouseTheme.blue)
                .frame(width: 88, height: 5)
        }
    }

    private func resultHero(_ session: GameSession) -> some View {
        let winnerNames = winners(for: session).map(\.name)
        let title: String
        let subtitle: String

        if winnerNames.count == 1, let winner = winnerNames.first {
            title = "\(winner) wins"
            subtitle = "Tonight belongs to \(winner)."
        } else if winnerNames.count > 1 {
            title = "It’s a tie"
            subtitle = winnerNames.joined(separator: " • ")
        } else {
            title = "No winner"
            subtitle = "A perfectly unresolved game night."
        }

        return VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
            HStack(alignment: .center, spacing: AppTheme.spacingMedium) {
                ZStack {
                    Circle()
                        .fill(ClubhouseTheme.yellow)
                        .frame(width: 68, height: 68)

                    BauhausStarburst(color: ClubhouseTheme.ink, size: 34)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(AppFonts.hero)
                        .foregroundStyle(ClubhouseTheme.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)
                        .accessibilityIdentifier("winner_text")

                    Text(subtitle)
                        .font(AppFonts.body)
                        .foregroundStyle(ClubhouseTheme.inkMuted)
                }
            }

            HStack(spacing: 8) {
                ForEach(0..<min(max(session.sortedRounds.count, 1), 8), id: \.self) { index in
                    Capsule()
                        .fill(index.isMultiple(of: 2) ? ClubhouseTheme.blue : ClubhouseTheme.red)
                        .frame(maxWidth: .infinity)
                        .frame(height: 7)
                }
            }
        }
        .padding(AppTheme.spacingLarge)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge, isInteractive: true)
        .accessibilityElement(children: .combine)
    }

    private func standingsCard(_ session: GameSession) -> some View {
        let winnerIDs = Set(winners(for: session).map(\.id))

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Final Scores")
                        .font(AppFonts.title)
                        .foregroundStyle(ClubhouseTheme.ink)

                    Text(session.winCondition == .highestScore ? "Highest score wins" : "Lowest score wins")
                        .font(AppFonts.caption)
                        .foregroundStyle(ClubhouseTheme.inkMuted)
                }

                Spacer()

                StampBadge(text: "Final")
            }
            .padding(AppTheme.spacingMedium)

            Rectangle()
                .fill(ClubhouseTheme.rule)
                .frame(height: 1)

            ForEach(Array(sortedPlayers(session).enumerated()), id: \.element.id) { index, player in
                LedgerRow(
                    player: player,
                    score: player.totalScore(in: session),
                    rank: index + 1,
                    subtitle: playerRoundSubtitle(player, session: session),
                    isLeader: winnerIDs.contains(player.id),
                    isHighlighted: winnerIDs.contains(player.id)
                )
            }
        }
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Game over standings")
    }

    private func actionStack(_ session: GameSession) -> some View {
        VStack(spacing: AppTheme.spacingSmall) {
            AppActionButton(role: .primary(ClubhouseTheme.blue)) {
                playAgain(session)
            } label: {
                Label("Play Again", systemImage: "arrow.clockwise.circle.fill")
            }
            .accessibilityIdentifier("play_again_button")

            AppActionButton(role: .secondary) {
                router.goHome()
            } label: {
                Label("Back Home", systemImage: "house")
            }
            .accessibilityIdentifier("home_button")
        }
    }

    private func recapGrid(_ session: GameSession) -> some View {
        let metrics = recapMetrics(session)

        return VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Game Recap")
                    .font(AppFonts.title)
                    .foregroundStyle(ClubhouseTheme.ink)

                Text("A quick memory of how the table finished.")
                    .font(AppFonts.caption)
                    .foregroundStyle(ClubhouseTheme.inkMuted)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.spacingSmall) {
                ForEach(metrics) { metric in
                    RecapMetricCard(metric: metric)
                }
            }
        }
        .padding(AppTheme.spacingMedium)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge)
    }

    private func shareButton(_ session: GameSession) -> some View {
        ShareLink(item: shareText(session)) {
            HStack(spacing: AppTheme.spacingSmall) {
                Image(systemName: "square.and.arrow.up")
                    .font(.headline)

                Text("Share Game Recap")
                    .font(AppFonts.headline)

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(ClubhouseTheme.ink)
            .padding(.horizontal, AppTheme.spacingMedium)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 58)
            .scorecardSurface(cornerRadius: AppTheme.cornerRadiusMedium, isInteractive: true)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityIdentifier("share_game_recap_button")
    }

    private func winners(for session: GameSession) -> [Player] {
        let winnerIDs = Set(GameEngineFactory.engine(for: session.gameType).winners(session: session))
        return session.players.filter { winnerIDs.contains($0.id) }
    }

    private func sortedPlayers(_ session: GameSession) -> [Player] {
        session.players.sorted { lhs, rhs in
            let lhsScore = lhs.totalScore(in: session)
            let rhsScore = rhs.totalScore(in: session)

            if lhsScore == rhsScore {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }

            return session.winCondition == .highestScore
                ? lhsScore > rhsScore
                : lhsScore < rhsScore
        }
    }

    private func playerRoundSubtitle(_ player: Player, session: GameSession) -> String {
        let scores = session.sortedRounds.compactMap { $0.entry(for: player.id)?.points }
        guard let best = session.winCondition == .highestScore ? scores.max() : scores.min() else {
            return "No submitted score"
        }

        return "Best round \(best > 0 ? "+\(best)" : "\(best)")"
    }

    private func recapMetrics(_ session: GameSession) -> [RecapMetric] {
        let roundScores = session.sortedRounds.flatMap { round in
            round.entries.map { entry in
                (entry.playerID, entry.points)
            }
        }

        let biggest = roundScores.max { lhs, rhs in
            abs(lhs.1) < abs(rhs.1)
        }

        let biggestPlayer = biggest.flatMap { item in
            session.players.first(where: { $0.id == item.0 })
        }

        let duration = session.completedAt.map { completion in
            completion.timeIntervalSince(session.createdAt)
        } ?? 0

        return [
            RecapMetric(title: "Rounds", value: "\(session.sortedRounds.count)", detail: "played", tint: ClubhouseTheme.blue),
            RecapMetric(title: "Players", value: "\(session.players.count)", detail: "at the table", tint: ClubhouseTheme.red),
            RecapMetric(
                title: "Biggest Round",
                value: biggest.map { $0.1 > 0 ? "+\($0.1)" : "\($0.1)" } ?? "—",
                detail: biggestPlayer?.name ?? "No scores",
                tint: ClubhouseTheme.green
            ),
            RecapMetric(title: "Duration", value: durationText(duration), detail: "game time", tint: ClubhouseTheme.yellow)
        ]
    }

    private func durationText(_ interval: TimeInterval) -> String {
        guard interval > 0 else { return "—" }
        let totalMinutes = max(Int(interval / 60), 1)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return minutes == 0 ? "\(hours)h" : "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
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
            let clonedPlayer = Player(name: player.name, colorIndex: player.colorIndex)
            clonedPlayer.session = newSession
            newSession.players.append(clonedPlayer)
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
        router.push(.scoring(newSession.persistentModelID))
    }

    private func evaluateReviewAskIfNeeded() {
        guard !didEvaluateReviewAsk else { return }
        didEvaluateReviewAsk = true
        reviewAskManager.considerReviewAsk(
            completedGameCount: completedGames.count,
            paywallPresentedThisSession: storeManager.paywallPresentedThisSession
        )
    }

    private func shareText(_ session: GameSession) -> String {
        let standings = sortedPlayers(session).enumerated().map { index, player in
            "\(index + 1). \(player.name) — \(player.totalScore(in: session))"
        }.joined(separator: "\n")

        return "PipCount game over — \(session.gameType.displayName)\n\(standings)\n\(session.sortedRounds.count.quantityText("round")) played."
    }
}

private struct RecapMetric: Identifiable {
    let title: String
    let value: String
    let detail: String
    let tint: Color

    var id: String { title }
}

private struct RecapMetricCard: View {
    let metric: RecapMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Circle()
                .fill(metric.tint)
                .frame(width: 10, height: 10)

            Text(metric.value)
                .font(AppFonts.scoreMedium)
                .monospacedDigit()
                .foregroundStyle(ClubhouseTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(metric.title)
                .font(AppFonts.caption.weight(.bold))
                .foregroundStyle(ClubhouseTheme.ink)

            Text(metric.detail)
                .font(AppFonts.caption)
                .foregroundStyle(ClubhouseTheme.inkMuted)
                .lineLimit(1)
        }
        .padding(AppTheme.spacingSmall)
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
        .background(ClubhouseTheme.paperSunken, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                .strokeBorder(ClubhouseTheme.rule, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}
