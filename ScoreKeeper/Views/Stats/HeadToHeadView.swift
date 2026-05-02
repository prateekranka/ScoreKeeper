import SwiftUI
import SwiftData

struct HeadToHeadView: View {
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
        List {
            Section("Select Players") {
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

            if !records.isEmpty {
                Section("Head to Head by Game") {
                    ForEach(records, id: \.id) { record in
                        recordCard(record)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowBackground(Color.clear)
                    }
                }
            } else if !playerA.isEmpty && !playerB.isEmpty && playerA != playerB {
                ContentUnavailableView(
                    "No Games Together",
                    systemImage: "person.2.slash",
                    description: Text("\(playerA) and \(playerB) haven't played this matchup yet.")
                )
            }
        }
        .scrollContentBackground(.hidden)
        .appBackground()
        .navigationTitle("Head to Head")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: playerA) { _, _ in expandedKeys = [] }
        .onChange(of: playerB) { _, _ in expandedKeys = [] }
    }

    private func recordCard(_ record: H2HRecord) -> some View {
        VStack(spacing: AppTheme.spacingMedium) {
            HStack {
                Label(record.gameType?.displayName ?? "All Games", systemImage: record.gameType?.icon ?? "chart.bar")
                    .font(AppFonts.headline)
                    .foregroundStyle(record.gameType?.color ?? .primary)

                Spacer()

                Text("\(record.gamesTogether) \(record.gamesTogether == 1 ? "game" : "games")")
                    .font(AppFonts.caption)
                    .foregroundStyle(.secondary)
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
        .appGlass(cornerRadius: AppTheme.cornerRadiusMedium)
    }

    private func winSummary(_ record: H2HRecord) -> some View {
        HStack(spacing: 0) {
            playerWinColumn(name: record.playerA, wins: record.aWins, rate: record.aWinRate, color: .blue)

            Text("vs")
                .font(AppFonts.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            playerWinColumn(name: record.playerB, wins: record.bWins, rate: record.bWinRate, color: .orange)
        }
    }

    private func playerWinColumn(name: String, wins: Int, rate: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(name)
                .font(AppFonts.body)
                .bold()
            Text("\(wins) \(wins == 1 ? "win" : "wins")")
                .font(AppFonts.scoreSmall)
                .bold()
                .foregroundStyle(color)
            Text(String(format: "%.0f%%", rate * 100))
                .font(AppFonts.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func winBar(_ record: H2HRecord) -> some View {
        GeometryReader { geo in
            let totalWins = record.aWins + record.bWins
            let aFraction = totalWins > 0 ? CGFloat(record.aWins) / CGFloat(totalWins) : 0.5

            HStack(spacing: 4) {
                Rectangle()
                    .fill(.blue)
                    .frame(width: max(geo.size.width * aFraction, totalWins == 0 ? geo.size.width / 2 : 4), height: 20)
                    .clipShape(.rect(cornerRadius: 6))

                Rectangle()
                    .fill(.orange)
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
                Text(name)
                    .font(AppFonts.body)

                Spacer()

                Image(systemName: isExpanded(player: name, record: record) ? "chevron.down" : "chevron.right")
                    .font(AppFonts.caption)
                    .foregroundStyle(.secondary)
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
                .foregroundStyle(.secondary)

            Spacer()

            Text(isWinner ? "Win" : winnerIDs.isEmpty ? "No winner" : "Loss")
                .font(AppFonts.caption)
                .foregroundStyle(isWinner ? .green : .secondary)

            if let player {
                Text("\(player.totalScore(in: session))")
                    .font(AppFonts.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, AppTheme.spacingSmall)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
    }

    private func key(player: String, record: H2HRecord) -> String {
        "\(record.gameType?.rawValue ?? "all"):\(player)"
    }

    private func isExpanded(player: String, record: H2HRecord) -> Bool {
        expandedKeys.contains(key(player: player, record: record))
    }

    private func toggleExpanded(player: String, record: H2HRecord) {
        let key = key(player: player, record: record)
        if expandedKeys.contains(key) {
            expandedKeys.remove(key)
        } else {
            expandedKeys.insert(key)
        }
    }
}
