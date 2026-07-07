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
            showsScoreboardHeader: false,
            action: submitRound
        ) {
            GenericFocusScoreTable(
                session: session,
                engine: engine,
                scores: scoreBinding(for:),
                winConditionLabel: session.winCondition == .highestScore ? "Highest wins" : "Lowest wins"
            )
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

private struct GenericFocusScoreTable: View {
    let session: GameSession
    let engine: GameEngine
    let scores: (Player) -> Binding<Int>
    let winConditionLabel: String

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()
                .padding(.horizontal, AppTheme.spacingMedium)

            VStack(spacing: 0) {
                tableHeader

                ForEach(Array(session.players.enumerated()), id: \.element.id) { index, player in
                    FocusScoreRow(
                        player: player,
                        totalScore: player.totalScore(in: session),
                        isLeading: leadingPlayers.contains(player.id),
                        value: scores(player)
                    )

                    if index < session.players.count - 1 {
                        Divider()
                            .padding(.leading, 64)
                    }
                }
            }
            .padding(.horizontal, AppTheme.spacingMedium)
            .padding(.bottom, AppTheme.spacingMedium)
        }
        .appGlass(cornerRadius: AppTheme.cornerRadiusMedium, isInteractive: true)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Round \(session.currentRoundNumber) score table, \(winConditionLabel)")
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppTheme.spacingSmall) {
            Label("Round \(session.currentRoundNumber)", systemImage: session.gameType.icon)
                .font(AppFonts.title)
                .foregroundStyle(session.gameType.color)
                .monospacedDigit()

            Spacer(minLength: AppTheme.spacingSmall)

            Text(winConditionLabel)
                .font(AppFonts.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .frame(minHeight: 28)
                .background(session.gameType.color.opacity(0.12), in: Capsule())
        }
        .padding(AppTheme.spacingMedium)
    }

    private var tableHeader: some View {
        HStack {
            Text("Player")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Total")
                .frame(width: 64, alignment: .trailing)
            Text("This round")
                .frame(width: 128, alignment: .trailing)
        }
        .font(AppFonts.caption)
        .foregroundStyle(.secondary)
        .textCase(.uppercase)
        .padding(.vertical, AppTheme.spacingSmall)
    }

    private var leadingPlayers: [UUID] {
        session.rounds.isEmpty ? [] : engine.winners(session: session)
    }
}

private struct FocusScoreRow: View {
    let player: Player
    let totalScore: Int
    let isLeading: Bool
    @Binding var value: Int
    var range: ClosedRange<Int> = -9999...9999
    var step = 1

    var body: some View {
        VStack(spacing: AppTheme.spacingSmall) {
            HStack(spacing: AppTheme.spacingSmall) {
                playerIdentity

                Spacer(minLength: AppTheme.spacingSmall)

                totalColumn

                scoreStepper
            }

            HStack(spacing: 6) {
                Spacer(minLength: 0)

                ForEach(quickAmounts, id: \.self) { amount in
                    quickButton(amount)
                }
            }
        }
        .padding(.vertical, AppTheme.spacingMedium)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(player.name), total score \(totalScore), round score \(value)")
    }

    private var playerIdentity: some View {
        HStack(spacing: AppTheme.spacingSmall) {
            ZStack {
                Circle()
                    .fill(PlayerColors.color(for: player.colorIndex))
                    .frame(width: 38, height: 38)

                Text(String(player.name.prefix(1)).uppercased())
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(player.name)
                        .font(AppFonts.headline)
                        .lineLimit(1)

                    if isLeading {
                        Image(systemName: "crown.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                            .accessibilityLabel("Leading")
                    }
                }

                Text("Round points")
                    .font(AppFonts.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var totalColumn: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("\(totalScore)")
                .font(AppFonts.scoreSmall)
                .monospacedDigit()
                .foregroundStyle(isLeading ? PlayerColors.color(for: player.colorIndex) : .primary)
                .contentTransition(.numericText())

            Text("total")
                .font(AppFonts.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 56, alignment: .trailing)
    }

    private var scoreStepper: some View {
        HStack(spacing: 6) {
            stepButton(systemImage: "minus.circle.fill", label: "Decrease score") {
                apply(-step)
            }

            Text("\(value)")
                .font(AppFonts.scoreSmall)
                .monospacedDigit()
                .frame(width: 42)
                .contentTransition(.numericText())
                .accessibilityLabel("Score \(value)")

            stepButton(systemImage: "plus.circle.fill", label: "Increase score") {
                apply(step)
            }
        }
        .frame(width: 128, alignment: .trailing)
    }

    private func stepButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifierPrefix + (label.hasPrefix("Decrease") ? "decrement" : "increment"))
    }

    private func quickButton(_ amount: Int) -> some View {
        Button("+\(amount)") {
            apply(amount)
        }
        .font(AppFonts.caption)
        .monospacedDigit()
        .foregroundStyle(.secondary)
        .padding(.horizontal, 9)
        .frame(minHeight: 30)
        .background(.regularMaterial, in: Capsule())
        .buttonStyle(PressableButtonStyle())
        .accessibilityIdentifier(identifierPrefix + "quick_\(amount)")
        .accessibilityLabel("Add \(amount) points")
    }

    private var identifierPrefix: String {
        "\(player.name)_"
    }

    private var quickAmounts: [Int] {
        Array(Set([step, step * 5, step * 10])).sorted()
    }

    private func apply(_ delta: Int) {
        let newValue = value + delta
        if range.contains(newValue) {
            value = newValue
        }
    }
}
