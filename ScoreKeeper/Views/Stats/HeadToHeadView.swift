import SwiftUI
import SwiftData

struct HeadToHeadView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(NavigationRouter.self) private var router
    @Query(sort: \GameSession.createdAt, order: .reverse) private var allSessions: [GameSession]
    @State private var playerA = ""
    @State private var playerB = ""
    @State private var expandedKeys: Set<String> = []

    private var completedSessions: [GameSession] {
        allSessions.filter(\.isComplete)
    }

    private var playerNames: [String] {
        StatsCalculator.allPlayerNames(from: completedSessions)
    }

    private var records: [H2HRecord] {
        guard !playerA.isEmpty, !playerB.isEmpty, playerA != playerB else { return [] }
        return StatsCalculator.headToHeadByGameType(playerA, vs: playerB, sessions: completedSessions)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
                selectionPanel

                if !records.isEmpty {
                    Text("Head to Head by Game")
                        .columnHeaderStyle()

                    ForEach(records, id: \.id) { record in
                        recordCard(record)
                    }
                } else if !playerA.isEmpty && !playerB.isEmpty && playerA != playerB {
                    ContentUnavailableView(
                        "No Games Together",
                        systemImage: "person.2.slash",
                        description: Text("\(playerA) and \(playerB) haven't played this matchup yet.")
                    )
                }
            }
            .padding(AppTheme.spacingMedium)
        }
        .appBackground()
        .navigationTitle("Head to Head")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: playerA) { _, _ in expandedKeys = [] }
        .onChange(of: playerB) { _, _ in expandedKeys = [] }
    }

    private var selectionPanel: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            Text("Select Players")
                .columnHeaderStyle()

            Picker("Player 1", selection: $playerA) {
                Text("Select...").tag("")
                ForEach(playerNames, id: \.self) {
                    Text($0).tag($0)
                }
            }

            Picker("Player 2", selection: $playerB) {
                Text("Select...").tag("")
                ForEach(playerNames.filter { $0 != playerA }, id: \.self) {
                    Text($0).tag($0)
                }
            }
        }
        .padding(AppTheme.spacingMedium)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge)
    }

    private func recordCard(_ record: H2HRecord) -> some View {
        VStack(spacing: AppTheme.spacingMedium) {
            HStack {
                Label(record.gameType?.displayName ?? "All Games", systemImage: record.gameType?.icon ?? "chart.bar")
                    .font(AppFonts.headline)
                    .foregroundStyle(record.gameType?.color ?? ClubhouseTheme.ink)

                Spacer()

                Text("\(record.gamesTogether) \(record.gamesTogether == 1 ? "game" : "games") together")
                    .font(AppFonts.caption)
                    .foregroundStyle(ClubhouseTheme.inkMuted)
            }

            winSummary(record)
            winBar(record)

            VStack(spacing: AppTheme.spacingSmall) {
                playerDisclosure(record.playerA, record: record)
                expandableGames(for: record.playerA, record: record)
                playerDisclosure(record.playerB, record: record)
                expandableGames(for: record.playerB, record: record)
            }
        }
        .padding(AppTheme.spacingMedium)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge)
    }

    private func winSummary(_ record: H2HRecord) -> some View {
        HStack(spacing: 0) {
            playerWinColumn(name: record.playerA, wins: record.aWins, rate: record.aWinRate, colorIndex: 3)

            Text("vs")
                .font(AppFonts.caption)
                .foregroundStyle(ClubhouseTheme.inkMuted)
                .padding(.horizontal)

            playerWinColumn(name: record.playerB, wins: record.bWins, rate: record.bWinRate, colorIndex: 4)
        }
    }

    private func playerWinColumn(name: String, wins: Int, rate: Double, colorIndex: Int) -> some View {
        Button {
            router.push(.playerStats(name))
        } label: {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    PlayerGlyph(colorIndex: colorIndex, font: AppFonts.caption)

                    Text(name)
                        .font(AppFonts.body)
                        .bold()
                        .foregroundStyle(ClubhouseTheme.ink)
                }
                Text("\(wins) \(wins == 1 ? "win" : "wins")")
                    .font(AppFonts.scoreSmall)
                    .monospacedDigit()
                    .foregroundStyle(PlayerColors.color(for: colorIndex))
                Text(String(format: "%.0f%%", rate * 100))
                    .font(AppFonts.caption)
                    .foregroundStyle(ClubhouseTheme.inkMuted)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .accessibilityHint("Opens player stats")
        .accessibilityIdentifier("player_stats_\(name)")
    }

    private func winBar(_ record: H2HRecord) -> some View {
        GeometryReader { geo in
            let totalWins = record.aWins + record.bWins
            let aFraction = totalWins > 0 ? CGFloat(record.aWins) / CGFloat(totalWins) : 0.5

            HStack(spacing: 4) {
                Rectangle()
                    .fill(PlayerColors.palette[3])
                    .frame(width: max(geo.size.width * aFraction, totalWins == 0 ? geo.size.width / 2 : 4), height: 20)
                    .clipShape(.rect(cornerRadius: 6))

                Rectangle()
                    .fill(PlayerColors.palette[4])
                    .frame(width: max(geo.size.width * (1 - aFraction), totalWins == 0 ? geo.size.width / 2 : 4), height: 20)
                    .clipShape(.rect(cornerRadius: 6))
            }
        }
        .frame(height: 28)
    }

    private func playerDisclosure(_ name: String, record: H2HRecord) -> some View {
        Button {
            toggleExpanded(player: name, record: record)
        } label: {
            HStack {
                PlayerGlyph(colorIndex: name == record.playerA ? 3 : 4, font: AppFonts.caption)

                Text(name)
                    .font(AppFonts.body)
                    .foregroundStyle(ClubhouseTheme.ink)

                Spacer()

                Image(systemName: isExpanded(player: name, record: record) ? "chevron.down" : "chevron.right")
                    .font(AppFonts.caption)
                    .foregroundStyle(ClubhouseTheme.inkMuted)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(name) recent \(record.gameType?.displayName ?? "games")")
    }

    @ViewBuilder
    private func expandableGames(for player: String, record: H2HRecord) -> some View {
        if isExpanded(player: player, record: record), let gameType = record.gameType {
            let games = StatsCalculator.gamesBetween(record.playerA, and: record.playerB, gameType: gameType, sessions: completedSessions)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(games.prefix(5)) { session in
                    recentGameRow(session, highlightedPlayer: player)
                }
            }
            .padding(.vertical, 4)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private func recentGameRow(_ session: GameSession, highlightedPlayer: String) -> some View {
        let engine = GameEngineFactory.engine(for: session.gameType)
        let winnerIDs = engine.winners(session: session)
        let player = session.players.first { $0.name == highlightedPlayer }
        let isWinner = player.map { winnerIDs.contains($0.id) } ?? false

        return HStack {
            Text(session.completedAt ?? session.createdAt, style: .date)
                .font(AppFonts.caption)
                .foregroundStyle(ClubhouseTheme.inkMuted)

            Spacer()

            Text(isWinner ? "Win" : winnerIDs.isEmpty ? "No winner" : "Loss")
                .font(AppFonts.caption)
                .foregroundStyle(isWinner ? ClubhouseTheme.felt : ClubhouseTheme.inkMuted)

            if let player {
                Text("\(player.totalScore(in: session))")
                    .font(AppFonts.caption)
                    .monospacedDigit()
                    .foregroundStyle(ClubhouseTheme.ink)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, AppTheme.spacingSmall)
        .background(ClubhouseTheme.paperSunken, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                .strokeBorder(ClubhouseTheme.rule, lineWidth: 1)
        }
    }

    private func key(player: String, record: H2HRecord) -> String {
        "\(record.gameType?.rawValue ?? "all"):\(player)"
    }

    private func isExpanded(player: String, record: H2HRecord) -> Bool {
        expandedKeys.contains(key(player: player, record: record))
    }

    private func toggleExpanded(player: String, record: H2HRecord) {
        let key = key(player: player, record: record)
        withAnimation(reduceMotion ? AppMotion.fade : AppMotion.state) {
            if expandedKeys.contains(key) {
                expandedKeys.remove(key)
            } else {
                expandedKeys.insert(key)
            }
        }
    }
}
