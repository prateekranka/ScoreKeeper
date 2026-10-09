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
            HStack {
                Text(title)
                    .font(AppFonts.title)
                    .foregroundStyle(ClubhouseTheme.ink)
                Spacer()
                StampBadge(text: "final")
            }

            ForEach(standings) { standing in
                LedgerRow(
                    player: standing.player,
                    score: standing.score,
                    rank: standing.rank,
                    isLeader: standing.isWinner,
                    isHighlighted: standing.isWinner
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(standing.player.name), rank \(standing.rank), score \(standing.score)\(standing.isWinner ? ", winner" : "")")
            }
        }
        .padding(AppTheme.spacingMedium)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge)
    }
}

extension GameSession {
    func standings(using engine: GameEngine) -> [PlayerStanding] {
        let winnerIDs = Set(engine.winners(session: self))
        return engine.rankedPlayers(session: self).map { player in
            PlayerStanding(
                id: player.id,
                rank: engine.rank(of: player, in: self),
                player: player,
                score: player.totalScore(in: self),
                isWinner: winnerIDs.contains(player.id)
            )
        }
    }
}
