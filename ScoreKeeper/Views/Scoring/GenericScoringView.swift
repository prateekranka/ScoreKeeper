import SwiftUI
import SwiftData

struct GenericScoringView: View {
    @Bindable var session: GameSession
    @Environment(\.modelContext) private var modelContext
    @State private var scores: [UUID: Int] = [:]
    @State private var scoreHapticTrigger = 0
    private let engine = GenericEngine()

    var body: some View {
        ScoringScreenLayout(
            session: session,
            engine: engine,
            actionTitle: "Submit Round",
            actionSystemImage: "checkmark.circle.fill",
            action: submitRound
        ) {
            RoundBanner(
                icon: session.gameType.icon,
                color: session.gameType.color,
                title: "Round \(session.currentRoundNumber)",
                subtitle: session.winCondition == .highestScore ? "Highest wins" : "Lowest wins"
            )

            ForEach(session.players, id: \.id) { player in
                ScoreEntryRow(
                    player: player,
                    value: scoreBinding(for: player),
                    title: "Round points"
                ) {
                    EmptyView()
                }
            }
        } footer: {
            RoundHistoryStrip(session: session)
        }
        .animation(.easeOut, value: session.sortedRounds.isEmpty)
        .sensoryFeedback(.impact, trigger: scoreHapticTrigger)
    }

    private func scoreBinding(for player: Player) -> Binding<Int> {
        Binding(
            get: { scores[player.id] ?? 0 },
            set: { scores[player.id] = $0 }
        )
    }

    private func submitRound() {
        let round = Round(roundNumber: session.currentRoundNumber)
        round.session = session

        for player in session.players {
            let points = scores[player.id] ?? 0
            let entry = ScoreEntry(playerID: player.id, points: points)
            entry.round = round
            round.entries.append(entry)
        }

        session.rounds.append(round)
        try? modelContext.save()

        // Reset scores
        scores = [:]

        scoreHapticTrigger += 1
    }
}
