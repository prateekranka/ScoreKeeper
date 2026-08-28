import SwiftData
import SwiftUI

struct PlayerStatsView: View {
    let playerName: String

    @Environment(NavigationRouter.self) private var router
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @Query(sort: \GameSession.createdAt, order: .reverse)
    private var allSessions: [GameSession]

    @State private var contentVisible = false

    private var completedSessions: [GameSession] {
        allSessions.filter(\.isComplete)
    }

    private var stats: PlayerStats {
        StatsCalculator.stats(for: playerName, sessions: completedSessions)
    }

    private var relevantSessions: [GameSession] {
        completedSessions
            .filter { session in
                session.players.contains { player in
                    player.name.caseInsensitiveCompare(playerName) == .orderedSame
                }
            }
            .prefix(12)
            .map { $0 }
    }

    private var metrics: [PlayerStatMetric] {
        [
            PlayerStatMetric(title: "Games", value: "\(stats.gamesPlayed)", detail: "played", tint: ClubhouseTheme.blue),
            PlayerStatMetric(title: "Wins", value: "\(stats.wins)", detail: "finished first", tint: ClubhouseTheme.red),
            PlayerStatMetric(title: "Win Rate", value: String(format: "%.0f%%", stats.winRate * 100), detail: "all games", tint: ClubhouseTheme.green),
            PlayerStatMetric(title: "Best Rank", value: stats.bestRank > 0 ? "#\(stats.bestRank)" : "—", detail: "best finish", tint: ClubhouseTheme.yellow),
            PlayerStatMetric(title: "Average", value: String(format: "%.0f", stats.avgScore), detail: "score", tint: ClubhouseTheme.ink)
        ]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacingLarge) {
                statsHero
                    .staggeredEntrance(visible: contentVisible, index: 0)

                responsiveContent
            }
            .padding(.horizontal, AppTheme.spacingMedium)
            .padding(.top, AppTheme.spacingSmall)
            .padding(.bottom, AppTheme.spacingLarge)
            .pipCountPageContent(maxWidth: 1_080)
        }
        .appBackground()
        .accessibilityIdentifier("player_stats_view")
        .navigationTitle(playerName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            contentVisible = true
        }
    }

    @ViewBuilder
    private var responsiveContent: some View {
        if horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize {
            HStack(alignment: .top, spacing: AppTheme.spacingLarge) {
                metricsPanel
                    .frame(width: 390)
                    .staggeredEntrance(visible: contentVisible, index: 1)

                recentGamesPanel
                    .frame(maxWidth: .infinity, alignment: .top)
                    .staggeredEntrance(visible: contentVisible, index: 2)
            }
        } else {
            VStack(spacing: AppTheme.spacingMedium) {
                metricsPanel
                    .staggeredEntrance(visible: contentVisible, index: 1)

                recentGamesPanel
                    .staggeredEntrance(visible: contentVisible, index: 2)
            }
        }
    }

    private var statsHero: some View {
        Group {
            if horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize {
                HStack(alignment: .center, spacing: AppTheme.spacingXXLarge) {
                    heroCopy
                        .frame(maxWidth: 390, alignment: .leading)

                    PipCountGeometricArtwork(scene: .onboardingHistory)
                        .frame(maxWidth: 500)
                        .frame(height: 300)
                }
            } else {
                HStack(alignment: .center, spacing: AppTheme.spacingMedium) {
                    heroCopy
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if !dynamicTypeSize.isAccessibilitySize {
                        PipCountGeometricArtwork(scene: .onboardingHistory)
                            .frame(width: 168, height: 174)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var heroCopy: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            Text(playerName)
                .font(AppFonts.hero)
                .foregroundStyle(ClubhouseTheme.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.72)

            Text("Every result, remembered.")
                .font(AppFonts.body)
                .foregroundStyle(ClubhouseTheme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)

            Rectangle()
                .fill(ClubhouseTheme.blue)
                .frame(width: 82, height: 4)
                .padding(.top, 4)
        }
    }

    private var metricsPanel: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
            VStack(alignment: .leading, spacing: 3) {
                Text("At a Glance")
                    .font(AppFonts.title)
                    .foregroundStyle(ClubhouseTheme.ink)

                Text("A lifetime record across completed games.")
                    .font(AppFonts.caption)
                    .foregroundStyle(ClubhouseTheme.inkMuted)
            }

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: AppTheme.spacingSmall
            ) {
                ForEach(metrics) { metric in
                    PlayerStatMetricCard(metric: metric)
                }
            }
        }
        .padding(AppTheme.spacingMedium)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge)
    }

    @ViewBuilder
    private var recentGamesPanel: some View {
        if relevantSessions.isEmpty {
            VStack(spacing: AppTheme.spacingMedium) {
                PipCountGeometricArtwork(scene: .homeEmpty, ambientMotion: false)
                    .frame(width: 190, height: 170)

                Text("No completed games yet")
                    .font(AppFonts.title)
                    .foregroundStyle(ClubhouseTheme.ink)

                Text("Finish a game with \(playerName) and their history will appear here.")
                    .font(AppFonts.body)
                    .foregroundStyle(ClubhouseTheme.inkMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(AppTheme.spacingLarge)
            .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge)
        } else {
            VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Recent Games")
                            .font(AppFonts.title)
                            .foregroundStyle(ClubhouseTheme.ink)

                        Text("Tap a result to reopen the full scorecard.")
                            .font(AppFonts.caption)
                            .foregroundStyle(ClubhouseTheme.inkMuted)
                    }

                    Spacer()

                    Text(relevantSessions.count.quantityText("result"))
                        .columnHeaderStyle()
                        .foregroundStyle(ClubhouseTheme.blue)
                }

                VStack(spacing: AppTheme.spacingSmall) {
                    ForEach(relevantSessions) { session in
                        Button {
                            router.push(.gameDetail(session.persistentModelID))
                        } label: {
                            recentGameRow(session)
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
            }
        }
    }

    private func recentGameRow(_ session: GameSession) -> some View {
        let engine = GameEngineFactory.engine(for: session.gameType)
        let winnerIDs = Set(engine.winners(session: session))
        let matchingPlayer = session.players.first {
            $0.name.caseInsensitiveCompare(playerName) == .orderedSame
        }
        let isWinner = matchingPlayer.map { winnerIDs.contains($0.id) } ?? false
        let score = matchingPlayer?.totalScore(in: session) ?? 0

        return HStack(spacing: AppTheme.spacingSmall) {
            GameTypeArtwork(gameType: session.gameType)
                .frame(width: 56, height: 56)
                .background(ClubhouseTheme.paperSunken, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(session.gameType.displayName)
                        .font(AppFonts.headline)
                        .foregroundStyle(ClubhouseTheme.ink)
                        .lineLimit(1)

                    if isWinner {
                        BrassCrown()
                    }
                }

                HStack(spacing: 6) {
                    if let date = session.completedAt {
                        Text(date, style: .date)
                    }

                    Text("•")
                    Text(session.sortedRounds.count.quantityText("round"))
                }
                .font(AppFonts.caption)
                .foregroundStyle(ClubhouseTheme.inkMuted)
            }

            Spacer(minLength: AppTheme.spacingSmall)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(score)")
                    .font(AppFonts.scoreSmall)
                    .monospacedDigit()
                    .foregroundStyle(isWinner ? ClubhouseTheme.brass : ClubhouseTheme.ink)

                Text(isWinner ? "Win" : "Finished")
                    .columnHeaderStyle()
                    .foregroundStyle(isWinner ? ClubhouseTheme.green : ClubhouseTheme.inkMuted)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(ClubhouseTheme.inkMuted)
        }
        .padding(AppTheme.spacingSmall)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusMedium, isInteractive: true)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

private struct PlayerStatMetric: Identifiable {
    let title: String
    let value: String
    let detail: String
    let tint: Color

    var id: String { title }
}

private struct PlayerStatMetricCard: View {
    let metric: PlayerStatMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Rectangle()
                .fill(metric.tint)
                .frame(width: 10, height: 10)
                .rotationEffect(.degrees(45))

            Text(metric.value)
                .font(AppFonts.scoreMedium)
                .monospacedDigit()
                .foregroundStyle(ClubhouseTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.62)

            Text(metric.title)
                .font(AppFonts.caption.weight(.bold))
                .foregroundStyle(ClubhouseTheme.ink)

            Text(metric.detail)
                .font(AppFonts.caption)
                .foregroundStyle(ClubhouseTheme.inkMuted)
                .lineLimit(1)
        }
        .padding(AppTheme.spacingSmall)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .background(ClubhouseTheme.paperSunken, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                .strokeBorder(ClubhouseTheme.rule, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}
