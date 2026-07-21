import SwiftUI
import SwiftData

struct GameDetailView: View {
    let sessionID: PersistentIdentifier
    @State private var sectionsVisible = false

    var body: some View {
        SessionLoader(sessionID: sessionID) { session in
            let engine = GameEngineFactory.engine(for: session.gameType)

            ScrollView {
                VStack(spacing: AppTheme.spacingLarge) {
                    DetailHeader(session: session)
                        .staggeredEntrance(visible: sectionsVisible, index: 0)
                    StandingsList(title: "Final Standings", standings: session.standings(using: engine))
                        .staggeredEntrance(visible: sectionsVisible, index: 1)
                    RoundBreakdownSection(session: session)
                        .staggeredEntrance(visible: sectionsVisible, index: 2)
                }
                .padding(AppTheme.spacingMedium)
            }
            .accessibilityIdentifier("game_detail_view")
            .appBackground()
            .navigationTitle("Game Details")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                sectionsVisible = true
            }
        }
    }
}

private struct DetailHeader: View {
    let session: GameSession

    private var dateText: String? {
        guard let date = session.completedAt else { return nil }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
            BauhausScreenHeader(
                title: session.gameType.displayName,
                subtitle: dateText.map { "Played \($0)" } ?? "Completed game",
                heroStyle: .gameOver
            )

            StatusPill(kind: .completed)
        }
        .padding(AppTheme.spacingMedium)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge)
        .accessibilityElement(children: .combine)
    }
}

private struct RoundBreakdownSection: View {
    let session: GameSession

    var body: some View {
        if !session.sortedRounds.isEmpty {
            VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                Text("Round Breakdown")
                    .columnHeaderStyle()

                ForEach(session.sortedRounds, id: \.id) { round in
                    RoundCard(round: round, players: session.players)
                }
            }
            .padding(AppTheme.spacingMedium)
            .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge)
        }
    }
}

private struct RoundCard: View {
    let round: Round
    let players: [Player]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Round \(round.roundNumber)")
                .columnHeaderStyle()

            ForEach(players, id: \.id) { player in
                HStack(spacing: AppTheme.spacingSmall) {
                    PlayerShapeIcon(colorIndex: player.colorIndex, size: 18)

                    Text(player.name)
                        .font(AppFonts.caption.weight(.semibold))
                        .foregroundStyle(ClubhouseTheme.ink)

                    Spacer()

                    Text("\(round.entry(for: player.id)?.points ?? 0)")
                        .font(AppFonts.caption.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(PlayerColors.color(for: player.colorIndex))
                        .contentTransition(.numericText(value: Double(round.entry(for: player.id)?.points ?? 0)))
                }
            }
        }
        .padding(AppTheme.spacingSmall)
        .background(ClubhouseTheme.paperSunken, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                .strokeBorder(ClubhouseTheme.panelBorder, lineWidth: 1)
        }
    }
}
