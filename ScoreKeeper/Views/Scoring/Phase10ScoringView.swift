import SwiftUI
import SwiftData

struct Phase10ScoringView: View {
    @Bindable var session: GameSession
    @Environment(\.modelContext) private var modelContext
    @Environment(NavigationRouter.self) private var router

    @State private var completedPhase: [UUID: Bool] = [:]
    @State private var showGameCompleteAlert = false
    @State private var pendingGameCompleteAlert = false
    @State private var scoreHapticTrigger = 0
    @State private var saveError: String?
    @State private var showDeck = false

    private let engine = Phase10Engine()

    var body: some View {
        ScoringScreenLayout(
            session: session,
            engine: engine,
            actionTitle: "score round",
            actionSystemImage: "square.and.pencil",
            showsScoreboardHeader: false,
            headerStyle: .compact,
            action: { showDeck = true }
        ) {
            phaseOverview
        } footer: {
            RoundHistoryStrip(session: session)
        }
        .fullScreenCover(isPresented: $showDeck, onDismiss: presentPendingGameCompleteAlert) {
            RoundEntryDeckView(
                session: session,
                accessory: { player in
                    stageControl(for: player)
                },
                onSubmit: { roundScores in
                    submitRound(using: roundScores)
                },
                onCancel: { showDeck = false }
            )
        }
        .sensoryFeedback(.impact, trigger: scoreHapticTrigger)
        .alert("ten phases complete", isPresented: $showGameCompleteAlert) {
            Button("keep playing", role: .cancel) {}
            Button("end game", role: .destructive) {
                finishGame()
            }
        } message: {
            Text("at least one player has completed all ten stages. you can end the game now or keep scoring")
        }
        .alert(
            "couldn’t save round",
            isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )
        ) {
            Button("ok", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "please try again")
        }
    }

    private var phaseOverview: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            AppSectionHeader(
                title: "current stages",
                subtitle: "write this round's leftover points with the score deck",
                systemImage: "flag.checkered"
            )

            ForEach(session.players, id: \.id) { player in
                let currentPhase = engine.currentPhase(for: player.id, in: session)
                let totalPoints = player.totalScore(in: session)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: AppTheme.spacingSmall) {
                        PlayerColorPip(colorIndex: player.colorIndex)

                        PlayerGlyph(colorIndex: player.colorIndex, font: AppFonts.caption)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(player.name)
                                .font(AppFonts.body)
                                .foregroundStyle(ClubhouseTheme.ink)
                                .lineLimit(1)

                            Text("\(totalPoints) \(totalPoints == 1 ? "point" : "points")")
                                .font(AppFonts.caption)
                                .foregroundStyle(ClubhouseTheme.inkMuted)
                                .monospacedDigit()
                        }

                        Spacer()

                        Text("stage \(currentPhase)/10")
                            .font(AppFonts.scoreSmall)
                            .monospacedDigit()
                            .foregroundStyle(currentPhase >= 10 ? ClubhouseTheme.felt : ClubhouseTheme.ink)

                        if currentPhase >= 10 {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(ClubhouseTheme.felt)
                        }
                    }

                    PegBoardStrip(currentPhase: currentPhase)
                }
                .padding(.vertical, AppTheme.spacingSmall)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(ClubhouseTheme.rule).frame(height: 1)
                }
            }
        }
        .padding(AppTheme.spacingMedium)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge)
    }

    /// The stage control rides inside the handwriting deck: it shows the stage
    /// the player is working on and records whether they completed it this
    /// round. The ranking rule (most stages wins, ties by fewest points) is
    /// unchanged and still lives in `Phase10Engine`.
    @ViewBuilder
    private func stageControl(for player: Player) -> some View {
        let currentPhase = engine.currentPhase(for: player.id, in: session)

        if currentPhase < 10 {
            if session.phase10SkipOnFail {
                Label("stage \(currentPhase + 1) completed", systemImage: "checkmark.circle.fill")
                    .font(AppFonts.caption)
                    .foregroundStyle(ClubhouseTheme.felt)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("stage_status_\(player.name)")
            } else {
                Toggle(isOn: completedPhaseBinding(for: player)) {
                    Text("stage \(currentPhase + 1) completed")
                        .font(AppFonts.caption)
                }
                .toggleStyle(.switch)
                .tint(ClubhouseTheme.felt)
                .accessibilityIdentifier("stage_toggle_\(player.name)")
            }
        } else {
            Label("all ten stages done", systemImage: "checkmark.seal.fill")
                .font(AppFonts.caption)
                .foregroundStyle(ClubhouseTheme.felt)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("stage_status_\(player.name)")
        }
    }

    private func completedPhaseBinding(for player: Player) -> Binding<Bool> {
        Binding(
            get: { completedPhase[player.id] ?? false },
            set: { completedPhase[player.id] = $0 }
        )
    }

    /// Returns nil after a successful save (the deck then dismisses); returns
    /// a user-facing message when the round cannot be saved, so the deck can
    /// stay open with the confirmed scores intact (PC17-003).
    private func submitRound(using roundScores: [UUID: Int]) -> String? {
        // The save boundary rejects incomplete dictionaries; it never
        // substitutes zero for a player who did not confirm a score.
        guard session.players.allSatisfy({ roundScores[$0.id] != nil }) else {
            return "every player needs a confirmed score before this round can save"
        }

        let round = Round(roundNumber: session.currentRoundNumber)
        round.session = session

        for player in session.players {
            guard let points = roundScores[player.id] else {
                return "every player needs a confirmed score before this round can save"
            }
            let currentPhase = engine.currentPhase(for: player.id, in: session)
            let didComplete = completedPhase[player.id] ?? false
            let nextPhase = min(currentPhase + 1, 10)

            let metadata = Phase10Metadata(
                phaseCompleted: (didComplete || session.phase10SkipOnFail) ? nextPhase : 0,
                leftoverPoints: points
            )

            let entry = ScoreEntry(playerID: player.id, points: points)
            entry.phase10Metadata = metadata
            entry.round = round
            round.entries.append(entry)
        }

        session.rounds.append(round)

        do {
            try modelContext.save()
        } catch {
            let message = error.localizedDescription
            modelContext.rollback()
            return message
        }

        showDeck = false
        if engine.isGameOver(session: session) {
            // The deck owns the screen until its cover dismisses; present the
            // completion alert from the dismissal so it cannot be dropped.
            pendingGameCompleteAlert = true
        }

        completedPhase = [:]
        scoreHapticTrigger += 1
        return nil
    }

    private func presentPendingGameCompleteAlert() {
        guard pendingGameCompleteAlert else { return }
        pendingGameCompleteAlert = false
        showGameCompleteAlert = true
    }

    private func finishGame() {
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
        router.push(.gameOver(session.persistentModelID))
    }
}

private struct PegBoardStrip: View {
    let currentPhase: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...10, id: \.self) { phase in
                Circle()
                    .fill(phase < currentPhase ? ClubhouseTheme.felt : phase == currentPhase ? ClubhouseTheme.brass : ClubhouseTheme.paperSunken)
                    .frame(width: 13, height: 13)
                    .overlay {
                        Circle()
                            .strokeBorder(ClubhouseTheme.rule, lineWidth: 1)
                    }
                    .accessibilityHidden(true)
            }
        }
    }
}
