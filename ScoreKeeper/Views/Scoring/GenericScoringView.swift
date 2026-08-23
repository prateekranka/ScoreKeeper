import SwiftUI
import SwiftData

struct GenericScoringView: View {
    @Bindable var session: GameSession
    @Environment(\.modelContext) private var modelContext
    @Environment(NavigationRouter.self) private var router
    @State private var scores: [UUID: Int] = [:]
    @State private var scoreHapticTrigger = 0
    @State private var saveError: String?
    @State private var didRouteToGameOver = false

    private let engine = GenericEngine()

    var body: some View {
        ScoringScreenLayout(
            session: session,
            engine: engine,
            actionTitle: "Submit Round",
            actionSystemImage: "checkmark.circle.fill",
            showsScoreboardHeader: false,
            headerStyle: .compact,
            showsToolsBar: false,
            action: endRound
        ) {
            CompactRoundScoreTable(
                session: session,
                engine: engine,
                scores: scoreBinding(for:),
                winConditionLabel: session.winCondition == .highestScore ? "Highest wins" : "Lowest wins"
            )
        } footer: {
            RoundHistoryStrip(session: session)
        }
        .sensoryFeedback(.impact, trigger: scoreHapticTrigger)
        .alert(
            "Couldn’t save round",
            isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "Please try again.")
        }
    }

    private func scoreBinding(for player: Player) -> Binding<Int> {
        Binding(
            get: { scores[player.id] ?? 0 },
            set: { scores[player.id] = $0 }
        )
    }

    private func endRound() {
        submitRound(using: scores)
    }

    private func submitRound(using roundScores: [UUID: Int]) {
        let round = Round(roundNumber: session.currentRoundNumber)
        round.session = session

        for player in session.players {
            let points = roundScores[player.id] ?? 0
            let entry = ScoreEntry(playerID: player.id, points: points)
            entry.round = round
            round.entries.append(entry)
        }

        session.rounds.append(round)

        do {
            try modelContext.save()
        } catch {
            let message = error.localizedDescription
            modelContext.rollback()
            saveError = message
            return
        }

        // Reset scores
        scores = [:]

        scoreHapticTrigger += 1

        if engine.isGameOver(session: session) {
            finishGame()
        }
    }

    private func finishGame() {
        guard !didRouteToGameOver else { return }

        session.isComplete = true
        session.completedAt = .now
        session.winnerID = engine.winners(session: session).first

        do {
            try modelContext.save()
        } catch {
            let message = error.localizedDescription
            modelContext.rollback()
            saveError = message
            return
        }

        didRouteToGameOver = true
        router.push(.gameOver(session.persistentModelID))
    }
}

private struct CompactRoundScoreTable: View {
    let session: GameSession
    let engine: GameEngine
    let scores: (Player) -> Binding<Int>
    let winConditionLabel: String

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Players")
                        .font(AppFonts.title)
                        .foregroundStyle(ClubhouseTheme.ink)
                    Text("Enter each player's round points, then submit.")
                        .font(AppFonts.caption)
                        .foregroundStyle(ClubhouseTheme.inkMuted)
                }

                Spacer(minLength: AppTheme.spacingSmall)

                Text(winConditionLabel)
                    .columnHeaderStyle()
                    .foregroundStyle(ClubhouseTheme.blue)
            }
            .padding(AppTheme.spacingMedium)

            Rectangle()
                .fill(ClubhouseTheme.rule)
                .frame(height: 1)

            ForEach(Array(session.players.enumerated()), id: \.element.id) { index, player in
                CompactRoundScoreRow(
                    player: player,
                    totalScore: player.totalScore(in: session),
                    isLeading: leadingPlayers.contains(player.id),
                    value: scores(player)
                )

                if index < session.players.count - 1 {
                    Rectangle()
                        .fill(ClubhouseTheme.rule)
                        .frame(height: 1)
                        .padding(.leading, 64)
                }
            }
        }
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge, isInteractive: true)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Round \(session.currentRoundNumber) players, \(winConditionLabel)")
    }

    private var leadingPlayers: [UUID] {
        session.rounds.isEmpty ? [] : engine.winners(session: session)
    }
}

private struct CompactRoundScoreRow: View {
    let player: Player
    let totalScore: Int
    let isLeading: Bool
    @Binding var value: Int

    var body: some View {
        HStack(spacing: AppTheme.spacingSmall) {
            BauhausPlayerShape(colorIndex: player.colorIndex, size: 38)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(player.name)
                        .font(AppFonts.headline)
                        .foregroundStyle(ClubhouseTheme.ink)
                        .lineLimit(1)
                    if isLeading {
                        BrassCrown()
                            .accessibilityLabel("Leading")
                    }
                }

                Text("Total \(totalScore)")
                    .font(AppFonts.caption)
                    .foregroundStyle(isLeading ? ClubhouseTheme.brass : ClubhouseTheme.inkMuted)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(totalScore)))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            PipStepper(
                value: $value,
                range: -9999...9999,
                step: 1,
                identifierPrefix: "\(player.name)_"
            )
            .frame(width: 188)
        }
        .padding(.horizontal, AppTheme.spacingMedium)
        .padding(.vertical, 9)
        .background(value == 0 ? Color.clear : PlayerColors.lightColor(for: player.colorIndex))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(player.name), total score \(totalScore), round score \(value)")
    }
}
