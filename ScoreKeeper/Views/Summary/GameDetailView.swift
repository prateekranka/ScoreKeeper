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
                withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
                    sectionsVisible = true
                }
            }
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

            if let date = session.completedAt {
                Text(date, style: .date)
                    .font(AppFonts.caption)
                    .foregroundStyle(.secondary)
            }
        }
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
            .appGlass(cornerRadius: AppTheme.cornerRadiusMedium)
        }
    }
}

private struct RoundCard: View {
    let round: Round
    let players: [Player]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Round \(round.roundNumber)")
                .font(AppFonts.caption)
                .foregroundStyle(.secondary)

            ForEach(players, id: \.id) { player in
                HStack(spacing: AppTheme.spacingSmall) {
                    Circle()
                        .fill(PlayerColors.color(for: player.colorIndex))
                        .frame(width: 10, height: 10)
                        .accessibilityHidden(true)

                    Text(player.name)
                        .font(AppFonts.caption)

                    Spacer()

                    Text("\(round.entry(for: player.id)?.points ?? 0)")
                        .font(AppFonts.caption)
                        .monospacedDigit()
                }
            }
        }
        .padding(AppTheme.spacingSmall)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
    }
}
