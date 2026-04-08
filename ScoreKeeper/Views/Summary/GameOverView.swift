import SwiftUI
import SwiftData

struct GameOverView: View {
    let sessionID: PersistentIdentifier
    @Environment(\.modelContext) private var modelContext
    @Environment(NavigationRouter.self) private var router

    var body: some View {
        SessionLoader(sessionID: sessionID) { session in
            gameOverContent(session)
        }
    }

    @ViewBuilder
    private func gameOverContent(_ session: GameSession) -> some View {
        let engine = GameEngineFactory.engine(for: session.gameType)
        let winnerIDs = engine.winners(session: session)
        let winner = session.players.first { winnerIDs.contains($0.id) }

        ZStack {
            ScrollView {
                VStack(spacing: AppTheme.spacingLarge) {
                    Spacer(minLength: 40)

                    // Winner announcement
                    VStack(spacing: AppTheme.spacingSmall) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.yellow)

                        if let winner {
                            Text("\(winner.name) wins!")
                                .font(AppFonts.largeTitle)
                                .foregroundStyle(PlayerColors.color(for: winner.colorIndex))
                        } else {
                            Text("Game Over!")
                                .font(AppFonts.largeTitle)
                        }

                        Text(session.gameType.displayName)
                            .font(AppFonts.body)
                            .foregroundStyle(.secondary)
                    }

                    // Final scores
                    VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                        Text("Final Scores")
                            .font(AppFonts.headline)

                        let sortedPlayers = session.players.sorted { p1, p2 in
                            let s1 = engine.totalScore(for: session.rounds.flatMap(\.entries).filter { $0.playerID == p1.id })
                            let s2 = engine.totalScore(for: session.rounds.flatMap(\.entries).filter { $0.playerID == p2.id })
                            return session.winCondition == .lowestScore ? s1 < s2 : s1 > s2
                        }

                        ForEach(Array(sortedPlayers.enumerated()), id: \.element.id) { index, player in
                            let score = engine.totalScore(for:
                                session.rounds.flatMap(\.entries).filter { $0.playerID == player.id }
                            )
                            let isWinner = winnerIDs.contains(player.id)

                            HStack(spacing: AppTheme.spacingSmall) {
                                Text("\(index + 1)")
                                    .font(AppFonts.headline)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 24)

                                PlayerBadge(name: player.name, colorIndex: player.colorIndex, size: .small, showName: false)

                                Text(player.name)
                                    .font(AppFonts.body)

                                Spacer()

                                Text("\(score)")
                                    .font(AppFonts.scoreSmall)
                                    .foregroundStyle(isWinner ? PlayerColors.color(for: player.colorIndex) : .primary)

                                if isWinner {
                                    Image(systemName: "crown.fill")
                                        .foregroundStyle(.yellow)
                                        .font(.caption)
                                }
                            }
                            .padding(AppTheme.spacingSmall)
                            .background(
                                isWinner ?
                                    AnyShapeStyle(PlayerColors.lightColor(for: player.colorIndex)) :
                                    AnyShapeStyle(.clear),
                                in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                            )
                        }
                    }
                    .padding(AppTheme.spacingMedium)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))

                    // Action buttons
                    VStack(spacing: AppTheme.spacingSmall) {
                        Button {
                            playAgain(session)
                        } label: {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Play Again")
                            }
                            .font(AppFonts.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                                    .fill(session.gameType.color)
                            )
                        }
                        .buttonStyle(.plain)

                        Button {
                            router.goHome()
                        } label: {
                            Text("Home")
                                .font(AppFonts.body)
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer(minLength: 40)
                }
                .padding(AppTheme.spacingMedium)
            }

            ConfettiOverlay()
                .ignoresSafeArea()
        }
        .appBackground()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func playAgain(_ session: GameSession) {
        let newSession = GameSession(gameType: session.gameType)
        newSession.winCondition = session.winCondition
        newSession.targetScore = session.targetScore
        modelContext.insert(newSession)

        for player in session.players {
            let newPlayer = Player(name: player.name, colorIndex: player.colorIndex)
            newPlayer.session = newSession
            newSession.players.append(newPlayer)
        }

        try? modelContext.save()

        router.goHome()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            router.push(.scoring(newSession.persistentModelID))
        }
    }
}
