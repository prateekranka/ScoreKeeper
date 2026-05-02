import SwiftUI

struct PlayerStanding: Identifiable {
    let id: UUID
    let rank: Int
    let player: Player
    let score: Int
    let isWinner: Bool
}

struct StandingsList: View {
    let title: String
    let standings: [PlayerStanding]

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            AppSectionHeader(title: title, systemImage: "trophy")

            ForEach(standings) { standing in
                HStack(spacing: AppTheme.spacingSmall) {
                    Text("\(standing.rank)")
                        .font(AppFonts.headline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .frame(width: 28)

                    PlayerBadge(
                        name: standing.player.name,
                        colorIndex: standing.player.colorIndex,
                        size: .small,
                        showName: false
                    )

                    Text(standing.player.name)
                        .font(AppFonts.body)
                        .lineLimit(1)

                    Spacer()

                    Text("\(standing.score)")
                        .font(AppFonts.scoreSmall)
                        .foregroundStyle(standing.isWinner ? PlayerColors.color(for: standing.player.colorIndex) : .primary)
                        .monospacedDigit()

                    if standing.isWinner {
                        Image(systemName: "crown.fill")
                            .foregroundStyle(.yellow)
                            .accessibilityLabel("Winner")
                    }
                }
                .padding(AppTheme.spacingSmall)
                .background(
                    standing.isWinner ? PlayerColors.lightColor(for: standing.player.colorIndex) : Color.clear,
                    in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(standing.player.name), rank \(standing.rank), score \(standing.score)\(standing.isWinner ? ", winner" : "")")
            }
        }
        .padding(AppTheme.spacingMedium)
        .appGlass(cornerRadius: AppTheme.cornerRadiusMedium)
    }
}

extension GameSession {
    func standings(using engine: GameEngine) -> [PlayerStanding] {
        let winnerIDs = engine.winners(session: self)
        let sortedPlayers = players.sorted { first, second in
            let firstScore = first.totalScore(in: self)
            let secondScore = second.totalScore(in: self)
            return winCondition == .lowestScore ? firstScore < secondScore : firstScore > secondScore
        }

        return sortedPlayers.enumerated().map { index, player in
            PlayerStanding(
                id: player.id,
                rank: index + 1,
                player: player,
                score: player.totalScore(in: self),
                isWinner: winnerIDs.contains(player.id)
            )
        }
    }
}
