import SwiftUI
import SwiftData

struct Phase10ScoringView: View {
    @Bindable var session: GameSession
    @Environment(\.modelContext) private var modelContext
    @Environment(NavigationRouter.self) private var router
    @Environment(StoreManager.self) private var storeManager
    @Environment(ReviewAskManager.self) private var reviewAskManager
    @State private var leftoverPoints: [UUID: Int] = [:]
    @State private var completedPhase: [UUID: Bool] = [:]
    @State private var showGameCompleteAlert = false
    @State private var scoreHapticTrigger = 0

    private let engine = Phase10Engine()

    var body: some View {
        ScoringScreenLayout(
            session: session,
            engine: engine,
            actionTitle: "Submit",
            actionSystemImage: "checkmark.circle.fill",
            action: submitRound
        ) {
            RoundBanner(
                icon: GameType.phase10.icon,
                color: GameType.phase10.color,
                title: "Round \(session.currentRoundNumber)",
                subtitle: "Complete all 10 phases"
            )
            phaseOverview
            roundEntrySection
        } footer: {
            RoundHistoryStrip(session: session)
        }
        .animation(.easeOut, value: session.sortedRounds.isEmpty)
        .sensoryFeedback(.impact, trigger: scoreHapticTrigger)
        .alert("Phase 10 complete", isPresented: $showGameCompleteAlert) {
            Button("Keep Playing", role: .cancel) {}
            Button("End Game", role: .destructive) {
                finishGame()
            }
        } message: {
            Text("At least one player has completed phase 10. You can end the game now or keep scoring.")
        }
    }

    private var phaseOverview: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            AppSectionHeader(title: "Current Phases", systemImage: "flag.checkered")

            ForEach(session.players, id: \.id) { player in
                let currentPhase = engine.currentPhase(for: player.id, in: session)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: AppTheme.spacingSmall) {
                        PlayerColorPip(colorIndex: player.colorIndex)

                        PlayerGlyph(colorIndex: player.colorIndex, font: AppFonts.caption)

                        Text(player.name)
                            .font(AppFonts.body)
                            .foregroundStyle(ClubhouseTheme.ink)

                        Spacer()

                        Text("Phase \(currentPhase)/10")
                            .font(AppFonts.scoreSmall)
                            .monospacedDigit()
                            .contentTransition(.numericText(value: Double(currentPhase)))
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

    private var roundEntrySection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            AppSectionHeader(title: "This Round", systemImage: "square.and.pencil")

            ForEach(session.players, id: \.id) { player in
                let currentPhase = engine.currentPhase(for: player.id, in: session)

                ScoreEntryRow(
                    player: player,
                    value: leftoverPointsBinding(for: player),
                    range: 0...9999,
                    step: 5,
                    title: "Leftover points"
                ) {
                    phaseAccessory(for: player, currentPhase: currentPhase)
                }
            }
        }
    }

    @ViewBuilder
    private func phaseAccessory(for player: Player, currentPhase: Int) -> some View {
        if currentPhase < 10 {
            if session.phase10SkipOnFail {
                Label("Phase \(currentPhase + 1) completed", systemImage: "checkmark.circle.fill")
                    .font(AppFonts.caption)
                    .foregroundStyle(ClubhouseTheme.felt)
            } else {
                Toggle(isOn: completedPhaseBinding(for: player)) {
                    Text("Phase \(currentPhase + 1)")
                        .font(AppFonts.caption)
                }
                .toggleStyle(.switch)
                .tint(ClubhouseTheme.felt)
            }
        } else {
            Label("All phases done", systemImage: "checkmark.seal.fill")
                .font(AppFonts.caption)
                .foregroundStyle(ClubhouseTheme.felt)
        }
    }

    private func completedPhaseBinding(for player: Player) -> Binding<Bool> {
        Binding(
            get: { completedPhase[player.id] ?? false },
            set: { completedPhase[player.id] = $0 }
        )
    }

    private func leftoverPointsBinding(for player: Player) -> Binding<Int> {
        Binding(
            get: { leftoverPoints[player.id] ?? 0 },
            set: { leftoverPoints[player.id] = $0 }
        )
    }

    private func submitRound() {
        let round = Round(roundNumber: session.currentRoundNumber)
        round.session = session

        for player in session.players {
            let currentPhase = engine.currentPhase(for: player.id, in: session)
            let didComplete = completedPhase[player.id] ?? false
            let points = leftoverPoints[player.id] ?? 0
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

        if engine.isGameOver(session: session) {
            showGameCompleteAlert = true
        }

        try? modelContext.save()

        leftoverPoints = [:]
        completedPhase = [:]

        scoreHapticTrigger += 1
    }

    private func finishGame() {
        session.isComplete = true
        session.completedAt = .now
        session.winnerID = engine.winners(session: session).first
        try? modelContext.save()
        let completedGameCount = fetchCompletedGameCount()
        let paywallPresentedThisSession = storeManager.paywallPresentedThisSession
        router.push(.gameOver(session.persistentModelID))
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1_000))
            reviewAskManager.considerReviewAsk(
                completedGameCount: completedGameCount,
                paywallPresentedThisSession: paywallPresentedThisSession
            )
        }
    }

    private func fetchCompletedGameCount() -> Int {
        let descriptor = FetchDescriptor<GameSession>(predicate: #Predicate { $0.isComplete })
        return (try? modelContext.fetch(descriptor).count) ?? 0
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
                            .stroke(ClubhouseTheme.rule, lineWidth: 1)
                    }
                    .accessibilityHidden(true)
            }
        }
    }
}
