import SwiftUI
import SwiftData

struct GameDetailView: View {
    let sessionID: PersistentIdentifier

    var body: some View {
        SessionLoader(sessionID: sessionID) { session in
            let engine = GameEngineFactory.engine(for: session.gameType)

            ScrollView {
                VStack(spacing: AppTheme.spacingLarge) {
                    DetailHeader(session: session)
                    StandingsList(title: "Final Standings", standings: session.standings(using: engine))
                    RoundBreakdownSection(session: session)
                }
                .padding(AppTheme.spacingMedium)
            }
            .accessibilityIdentifier("game_detail_view")
            .appBackground()
            .navigationTitle("Game Details")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct DetailHeader: View {
    let session: GameSession

    var body: some View {
        VStack(spacing: AppTheme.spacingSmall) {
            Image(systemName: session.gameType.icon)
                .font(.largeTitle)
                .foregroundStyle(session.gameType.color)
                .accessibilityHidden(true)

            Text(session.gameType.displayName)
                .font(AppFonts.title)
                .foregroundStyle(ClubhouseTheme.ink)

            if let date = session.completedAt {
                Text(date, style: .date)
                    .columnHeaderStyle()
            }

            StampBadge(text: "Final")
        }
        .padding(AppTheme.spacingLarge)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge)
        .accessibilityElement(children: .combine)
    }
}

private struct RoundBreakdownSection: View {
    let session: GameSession

    var body: some View {
        if !session.sortedRounds.isEmpty {
            VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                AppSectionHeader(title: "Round Breakdown", systemImage: "list.number")

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
        VStack(alignment: .leading, spacing: 4) {
            Text("Round \(round.roundNumber)")
                .columnHeaderStyle()

            ForEach(players, id: \.id) { player in
                HStack(spacing: AppTheme.spacingSmall) {
                    Circle()
                        .fill(PlayerColors.color(for: player.colorIndex))
                        .frame(width: 10, height: 10)
                        .accessibilityHidden(true)

                    PlayerGlyph(colorIndex: player.colorIndex, font: AppFonts.caption)

                    Text(player.name)
                        .font(AppFonts.caption)
                        .foregroundStyle(ClubhouseTheme.ink)

                    Spacer()

                    Text("\(round.entry(for: player.id)?.points ?? 0)")
                        .font(AppFonts.caption)
                        .monospacedDigit()
                        .foregroundStyle(ClubhouseTheme.ink)
                        .contentTransition(.numericText(value: Double(round.entry(for: player.id)?.points ?? 0)))
                }
            }
        }
        .padding(AppTheme.spacingSmall)
        .background(ClubhouseTheme.paperSunken, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                .strokeBorder(ClubhouseTheme.rule, lineWidth: 1)
        }
    }
}
