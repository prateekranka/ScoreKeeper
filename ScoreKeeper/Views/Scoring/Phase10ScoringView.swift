import SwiftUI
import SwiftData

struct Phase10ScoringView: View {
    @Bindable var session: GameSession
    @Environment(\.modelContext) private var modelContext
    @State private var leftoverPoints: [UUID: Int] = [:]
    @State private var completedPhase: [UUID: Bool] = [:]

    private let engine = Phase10Engine()

    var body: some View {
        VStack(spacing: 0) {
            roundInfo

            ScrollView {
                VStack(spacing: AppTheme.spacingMedium) {
                    phaseOverview
                    roundEntrySection
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
            Image(systemName: "10.circle.fill")
                .foregroundStyle(GameType.phase10.color)
            Text("Round \(session.currentRoundNumber)")
                .font(AppFonts.headline)
            Spacer()
            Text("Complete all 10 phases")
                .font(AppFonts.caption)
                .foregroundStyle(.secondary)
        }
        .padding(AppTheme.spacingMedium)
    }

    private var phaseOverview: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            Text("Current Phases")
                .font(AppFonts.headline)

            ForEach(session.players, id: \.id) { player in
                let currentPhase = engine.currentPhase(for: player.id, in: session)
                HStack(spacing: AppTheme.spacingSmall) {
                    PlayerBadge(name: player.name, colorIndex: player.colorIndex, size: .small, showName: false)

                    Text(player.name)
                        .font(AppFonts.body)

                    Spacer()

                    Text("Phase \(currentPhase)/10")
                        .font(AppFonts.scoreSmall)
                        .foregroundStyle(currentPhase >= 10 ? .green : GameType.phase10.color)

                    if currentPhase >= 10 {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }
        }
        .padding(AppTheme.spacingMedium)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
    }

    private var roundEntrySection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            Text("This Round")
                .font(AppFonts.headline)

            ForEach(session.players, id: \.id) { player in
                let currentPhase = engine.currentPhase(for: player.id, in: session)

                VStack(spacing: AppTheme.spacingSmall) {
                    HStack {
                        PlayerBadge(name: player.name, colorIndex: player.colorIndex, size: .small)
                            .frame(width: 70)

                        Spacer()

                        if currentPhase < 10 {
                            Toggle(isOn: Binding(
                                get: { completedPhase[player.id] ?? false },
                                set: { completedPhase[player.id] = $0 }
                            )) {
                                Text("Completed Phase \(currentPhase + 1)")
                                    .font(AppFonts.caption)
                            }
                            .toggleStyle(.switch)
                            .tint(.green)
                        } else {
                            Text("All phases done!")
                                .font(AppFonts.caption)
                                .foregroundStyle(.green)
                        }
                    }

                    HStack {
                        Text("Leftover points:")
                            .font(AppFonts.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        ScoreEntryField(
                            value: Binding(
                                get: { leftoverPoints[player.id] ?? 0 },
                                set: { leftoverPoints[player.id] = $0 }
                            ),
                            range: 0...9999,
                            step: 5
                        )
                    }
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
            Text("Submit Round")
                .font(AppFonts.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                        .fill(GameType.phase10.color)
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
                let meta = entry?.phase10Metadata
                HStack(spacing: 4) {
                    Circle()
                        .fill(PlayerColors.color(for: player.colorIndex))
                        .frame(width: 8, height: 8)

                    if let meta {
                        VStack(spacing: 0) {
                            if meta.phaseCompleted > 0 {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.green)
                            }
                            Text("\(entry?.points ?? 0)")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                        }
                    } else {
                        Text("\(entry?.points ?? 0)")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                    }
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
            let currentPhase = engine.currentPhase(for: player.id, in: session)
            let didComplete = completedPhase[player.id] ?? false
            let points = leftoverPoints[player.id] ?? 0

            let metadata = Phase10Metadata(
                phaseCompleted: didComplete ? currentPhase + 1 : 0,
                leftoverPoints: points
            )

            let entry = ScoreEntry(playerID: player.id, points: points)
            entry.phase10Metadata = metadata
            entry.round = round
            round.entries.append(entry)
        }

        session.rounds.append(round)

        // Check if game is over
        if engine.isGameOver(session: session) {
            // Auto-end handled by ScoringView's engine check or user manually ends
        }

        try? modelContext.save()

        leftoverPoints = [:]
        completedPhase = [:]

        HapticManager.shared.scoreEntry()
    }
}
