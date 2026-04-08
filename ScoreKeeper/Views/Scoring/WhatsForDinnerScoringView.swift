import SwiftUI
import SwiftData

struct WhatsForDinnerScoringView: View {
    @Bindable var session: GameSession
    @Environment(\.modelContext) private var modelContext
    @State private var handValues: [UUID: Int] = [:]
    @State private var callerID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            roundInfo

            ScrollView {
                VStack(spacing: AppTheme.spacingMedium) {
                    mealRevealSection
                    playerHandsSection
                    submitButton
                }
                .padding(AppTheme.spacingMedium)
            }

            if !session.sortedRounds.isEmpty {
                roundHistory
            }
        }
    }

    private var roundInfo: some View {
        HStack {
            Image(systemName: "fork.knife.circle.fill")
                .foregroundStyle(GameType.whatsForDinner.color)
            Text("Round \(session.currentRoundNumber)")
                .font(AppFonts.headline)
            Spacer()
            Text("Lowest total wins")
                .font(AppFonts.caption)
                .foregroundStyle(.secondary)
        }
        .padding(AppTheme.spacingMedium)
    }

    private var mealRevealSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            Text("Who called Meal Reveal?")
                .font(AppFonts.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.spacingSmall) {
                    ForEach(session.players, id: \.id) { player in
                        Button {
                            withAnimation {
                                callerID = player.id
                            }
                        } label: {
                            VStack(spacing: 4) {
                                PlayerBadge(
                                    name: player.name,
                                    colorIndex: player.colorIndex,
                                    size: .small,
                                    showName: true
                                )

                                if callerID == player.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                        .font(.caption)
                                }
                            }
                            .padding(AppTheme.spacingSmall)
                            .background(
                                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                                    .fill(callerID == player.id ?
                                          PlayerColors.lightColor(for: player.colorIndex) : .clear)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(AppTheme.spacingMedium)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
    }

    private var playerHandsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            Text("Card Values")
                .font(AppFonts.headline)

            ForEach(session.players, id: \.id) { player in
                HStack(spacing: AppTheme.spacingMedium) {
                    PlayerBadge(name: player.name, colorIndex: player.colorIndex, size: .small)
                        .frame(width: 70)

                    Spacer()

                    ScoreEntryField(
                        value: Binding(
                            get: { handValues[player.id] ?? 0 },
                            set: { handValues[player.id] = $0 }
                        ),
                        range: 0...9999
                    )
                }
                .padding(AppTheme.spacingSmall)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
            }
        }
    }

    private var submitButton: some View {
        Button {
            submitRound()
        } label: {
            HStack {
                Image(systemName: "fork.knife")
                Text("Submit Meal Reveal")
            }
            .font(AppFonts.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                    .fill(GameType.whatsForDinner.color)
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
            let points = handValues[player.id] ?? 0
            let entry = ScoreEntry(playerID: player.id, points: points)
            entry.round = round
            round.entries.append(entry)
        }

        session.rounds.append(round)
        try? modelContext.save()

        handValues = [:]
        callerID = nil

        HapticManager.shared.scoreEntry()
    }
}
