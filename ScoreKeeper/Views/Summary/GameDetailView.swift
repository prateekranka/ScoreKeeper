import SwiftUI
import SwiftData

struct GameDetailView: View {
    let sessionID: PersistentIdentifier
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        SessionLoader(sessionID: sessionID) { session in
            detailContent(session)
        }
    }

    @ViewBuilder
    private func detailContent(_ session: GameSession) -> some View {
        let engine = GameEngineFactory.engine(for: session.gameType)
        let winnerIDs = engine.winners(session: session)

        ScrollView {
            VStack(spacing: AppTheme.spacingLarge) {
                // Game info header
                VStack(spacing: AppTheme.spacingSmall) {
                    Image(systemName: session.gameType.icon)
                        .font(.system(size: 40))
                        .foregroundStyle(session.gameType.color)

                    Text(session.gameType.displayName)
                        .font(AppFonts.title)

                    if let date = session.completedAt {
                        Text(date, style: .date)
                            .font(AppFonts.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Final standings
                VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                    Text("Final Standings")
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

                            if isWinner {
                                Image(systemName: "crown.fill")
                                    .foregroundStyle(.yellow)
                                    .font(.caption)
                            }
                        }
                        .padding(AppTheme.spacingSmall)
                    }
                }
                .padding(AppTheme.spacingMedium)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))

                // Round-by-round breakdown
                if !session.sortedRounds.isEmpty {
                    VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                        Text("Round Breakdown")
                            .font(AppFonts.headline)

                        ForEach(session.sortedRounds, id: \.id) { round in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Round \(round.roundNumber)")
                                    .font(AppFonts.caption)
                                    .foregroundStyle(.secondary)

                                ForEach(session.players, id: \.id) { player in
                                    let entry = round.entry(for: player.id)
                                    HStack(spacing: AppTheme.spacingSmall) {
                                        Circle()
                                            .fill(PlayerColors.color(for: player.colorIndex))
                                            .frame(width: 10, height: 10)
                                        Text(player.name)
                                            .font(AppFonts.caption)
                                        Spacer()
                                        Text("\(entry?.points ?? 0)")
                                            .font(.system(size: 14, weight: .medium, design: .rounded))
                                    }
                                }
                            }
                            .padding(AppTheme.spacingSmall)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
                        }
                    }
                    .padding(AppTheme.spacingMedium)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
                }
            }
            .padding(AppTheme.spacingMedium)
        }
        .appBackground()
        .navigationTitle("Game Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}
