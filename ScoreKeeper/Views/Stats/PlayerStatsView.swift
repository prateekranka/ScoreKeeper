import SwiftUI
import SwiftData

struct PlayerStatsView: View {
    let playerName: String
    @Query(sort: \GameSession.createdAt, order: .reverse) private var allSessions: [GameSession]

    private var completedSessions: [GameSession] {
        allSessions.filter(\.isComplete)
    }

    private var stats: PlayerStats {
        StatsCalculator.stats(for: playerName, sessions: completedSessions)
    }

    var body: some View {
        List {
            Section("Overview") {
                statRow(label: "Games Played", value: "\(stats.gamesPlayed)")
                statRow(label: "Wins", value: "\(stats.wins)")
                statRow(label: "Win Rate", value: String(format: "%.0f%%", stats.winRate * 100))
                statRow(label: "Best Rank", value: stats.bestRank > 0 ? "#\(stats.bestRank)" : "—")
                statRow(label: "Avg Score", value: String(format: "%.0f", stats.avgScore))
            }

            if !statsRelevantSessions.isEmpty {
                Section("Recent Games") {
                    ForEach(statsRelevantSessions) { session in
                        HStack {
                            Image(systemName: session.gameType.icon)
                                .foregroundStyle(session.gameType.color)
                            VStack(alignment: .leading) {
                                Text(session.gameType.displayName)
                                    .font(.body)
                                if let date = session.completedAt {
                                    Text(date, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            let engine = GameEngineFactory.engine(for: session.gameType)
                            let winnerIDs = engine.winners(session: session)
                            let isWinner = session.players.contains { $0.name == playerName && winnerIDs.contains($0.id) }
                            Text(isWinner ? "Win" : "Loss")
                                .font(.caption)
                                .foregroundStyle(isWinner ? .green : .secondary)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .appBackground()
        .navigationTitle(playerName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var statsRelevantSessions: [GameSession] {
        completedSessions.filter { session in
            session.players.contains { $0.name == playerName }
        }.prefix(10).map { $0 }
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .monospacedDigit()
                .bold()
        }
    }
}
