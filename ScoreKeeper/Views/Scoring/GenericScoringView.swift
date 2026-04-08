import SwiftUI
import SwiftData

struct GenericScoringView: View {
    @Bindable var session: GameSession
    @Environment(\.modelContext) private var modelContext
    @State private var scores: [UUID: Int] = [:]

    var body: some View {
        VStack(spacing: 0) {
            roundInfo

            ScrollView {
                VStack(spacing: AppTheme.spacingMedium) {
                    ForEach(session.players, id: \.id) { player in
                        playerScoreRow(player)
                    }

                    submitButton
                }
                .padding(AppTheme.spacingMedium)
            }

            // Round history
            if !session.sortedRounds.isEmpty {
                roundHistory
            }
        }
    }

    private var roundInfo: some View {
        HStack {
            Text("Round \(session.currentRoundNumber)")
                .font(AppFonts.headline)
            Spacer()
            Text(session.winCondition == .highestScore ? "Highest wins" : "Lowest wins")
                .font(AppFonts.caption)
                .foregroundStyle(.secondary)
        }
        .padding(AppTheme.spacingMedium)
    }

    private func playerScoreRow(_ player: Player) -> some View {
        HStack(spacing: AppTheme.spacingMedium) {
            PlayerBadge(name: player.name, colorIndex: player.colorIndex, size: .small)
                .frame(width: 70)

            Spacer()

            ScoreEntryField(
                value: Binding(
                    get: { scores[player.id] ?? 0 },
                    set: { scores[player.id] = $0 }
                )
            )
        }
        .padding(AppTheme.spacingSmall)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
    }

    private var submitButton: some View {
        Button {
            submitRound()
        } label: {
            Text("Submit Round")
                .font(AppFonts.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                        .fill(session.gameType.color)
                )
        }
        .buttonStyle(.plain)
    }

    private var roundHistory: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            Text("Rounds")
                .font(AppFonts.headline)
                .padding(.horizontal, AppTheme.spacingMedium)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.spacingSmall) {
                    ForEach(session.sortedRounds, id: \.id) { round in
                        roundCard(round)
                    }
                }
                .padding(.horizontal, AppTheme.spacingMedium)
            }
        }
        .padding(.vertical, AppTheme.spacingSmall)
        .background(.ultraThinMaterial)
    }

    private func roundCard(_ round: Round) -> some View {
        VStack(spacing: 4) {
            Text("R\(round.roundNumber)")
                .font(AppFonts.caption)
                .foregroundStyle(.secondary)

            ForEach(session.players, id: \.id) { player in
                let entry = round.entry(for: player.id)
                HStack(spacing: 4) {
                    Circle()
                        .fill(PlayerColors.color(for: player.colorIndex))
                        .frame(width: 8, height: 8)
                    Text("\(entry?.points ?? 0)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                }
            }
        }
        .padding(AppTheme.spacingSmall)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
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

        HapticManager.shared.scoreEntry()
    }
}
