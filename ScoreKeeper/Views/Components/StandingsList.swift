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

    private var tiedRanks: Set<Int> {
        Dictionary(grouping: standings, by: \.rank)
            .filter { $0.value.count > 1 }
            .reduce(into: Set<Int>()) { $0.insert($1.key) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            HStack {
                Text(title)
                    .font(AppFonts.title)
                    .foregroundStyle(ClubhouseTheme.ink)
                Spacer()
                StampBadge(text: "Final")
            }

            ForEach(standings) { standing in
                LedgerRow(
                    player: standing.player,
                    score: standing.score,
                    rank: standing.rank,
                    isLeader: standing.isWinner,
                    isHighlighted: false,
                    trailingLabel: tiedRanks.contains(standing.rank) ? "TIE" : nil
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel(accessibilityLabel(for: standing))
            }
        }
        .padding(AppTheme.spacingMedium)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge)
    }

    private func accessibilityLabel(for standing: PlayerStanding) -> String {
        let rankText = tiedRanks.contains(standing.rank)
            ? "tied for rank \(standing.rank)"
            : "rank \(standing.rank)"
        return "\(standing.player.name), \(rankText), score \(standing.score)\(standing.isWinner ? ", winner" : "")"
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

        var result: [PlayerStanding] = []
        for (index, player) in sortedPlayers.enumerated() {
            let score = player.totalScore(in: self)
            let rank: Int
            if index > 0, score == result[index - 1].score {
                rank = result[index - 1].rank
            } else {
                rank = index + 1
            }
            result.append(
                PlayerStanding(
                    id: player.id,
                    rank: rank,
                    player: player,
                    score: score,
                    isWinner: winnerIDs.contains(player.id)
                )
            )
        }
        return result
    }
}
