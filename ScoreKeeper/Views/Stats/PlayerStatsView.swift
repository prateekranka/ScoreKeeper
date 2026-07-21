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
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
                BauhausScreenHeader(
                    title: playerName,
                    subtitle: "Games, wins, and recent nights.",
                    heroStyle: .players
                )

                Text("Overview")
                    .columnHeaderStyle()

                VStack(spacing: 0) {
                    statRow(label: "Games Played", value: "\(stats.gamesPlayed)")
                    statRow(label: "Wins", value: "\(stats.wins)")
                    statRow(label: "Win Rate", value: String(format: "%.0f%%", stats.winRate * 100))
                    statRow(label: "Best Rank", value: stats.bestRank > 0 ? "#\(stats.bestRank)" : "-")
                    statRow(label: "Avg Score", value: String(format: "%.0f", stats.avgScore))
                }
                .padding(AppTheme.spacingMedium)
                .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge)

                if !statsRelevantSessions.isEmpty {
                    Text("Recent Games")
                        .columnHeaderStyle()

                    ForEach(statsRelevantSessions) { session in
                        recentGameRow(session)
                    }
                }
            }
            .padding(AppTheme.spacingMedium)
        }
        .appBackground()
        .accessibilityIdentifier("player_stats_view")
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
                .font(AppFonts.body)
                .foregroundStyle(ClubhouseTheme.inkMuted)
            Spacer()
            Text(value)
                .font(AppFonts.scoreSmall)
                .monospacedDigit()
                .foregroundStyle(ClubhouseTheme.ink)
        }
        .padding(.vertical, AppTheme.spacingSmall)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(ClubhouseTheme.rule)
                .frame(height: 1)
        }
    }

    private func recentGameRow(_ session: GameSession) -> some View {
        let engine = GameEngineFactory.engine(for: session.gameType)
        let winnerIDs = engine.winners(session: session)
        let isWinner = session.players.contains { $0.name == playerName && winnerIDs.contains($0.id) }

        return HStack {
            Image(systemName: session.gameType.icon)
                .foregroundStyle(session.gameType.color)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.gameType.displayName)
                    .font(AppFonts.body.weight(.semibold))
                    .foregroundStyle(ClubhouseTheme.ink)
                if let date = session.completedAt {
                    Text(date, style: .date)
                        .font(AppFonts.caption)
                        .foregroundStyle(ClubhouseTheme.inkMuted)
                }
            }
            Spacer()
            StatusPill(kind: .custom(isWinner ? "Win" : "Loss", isWinner ? ClubhouseTheme.bauhausGreen : ClubhouseTheme.inkMuted))
        }
        .padding(AppTheme.spacingSmall)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusSmall, isInteractive: true)
    }
}
