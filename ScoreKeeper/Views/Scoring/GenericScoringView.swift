import SwiftUI
import SwiftData

struct GenericScoringView: View {
    @Bindable var session: GameSession
    @Environment(\.modelContext) private var modelContext
    @Environment(NavigationRouter.self) private var router
    @Environment(StoreManager.self) private var storeManager
    @Environment(ReviewAskManager.self) private var reviewAskManager
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
            actionSystemImage: "arrow.right.circle.fill",
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

private struct GenericFocusScoreTable: View {
    let session: GameSession
    let engine: GameEngine
    let scores: (Player) -> Binding<Int>
    let winConditionLabel: String

    var body: some View {
        VStack(spacing: 0) {
            header

            Rectangle()
                .fill(ClubhouseTheme.rule)
                .frame(height: 1)
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
                        Rectangle()
                            .fill(ClubhouseTheme.rule)
                            .frame(height: 1)
                            .padding(.leading, 64)
                    }
                }
            }
            .padding(.horizontal, AppTheme.spacingMedium)
            .padding(.bottom, AppTheme.spacingMedium)
        }
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge, isInteractive: true)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Round \(session.currentRoundNumber) score table, \(winConditionLabel)")
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppTheme.spacingSmall) {
            Label("Round \(session.currentRoundNumber)", systemImage: session.gameType.icon)
                .font(AppFonts.title)
                .foregroundStyle(ClubhouseTheme.ink)
                .monospacedDigit()

            Spacer(minLength: AppTheme.spacingSmall)

            Text(winConditionLabel)
                .columnHeaderStyle()
                .padding(.horizontal, 10)
                .frame(minHeight: 28)
                .background(ClubhouseTheme.paperSunken, in: Capsule())
                .overlay { Capsule().strokeBorder(ClubhouseTheme.rule, lineWidth: 1) }
        }
        .padding(AppTheme.spacingMedium)
    }

    private var tableHeader: some View {
        HStack {
            Text("Player")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Total")
                .frame(width: 64, alignment: .trailing)
        }
        .columnHeaderStyle()
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
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                    quickButtons
                    Spacer(minLength: 4)
                    scoreStepper
                }

                VStack(alignment: .trailing, spacing: AppTheme.spacingSmall) {
                    HStack(spacing: 6) {
                        quickButtons
                    }
                    scoreStepper
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.vertical, AppTheme.spacingMedium)
        .padding(.horizontal, AppTheme.spacingSmall)
        .background(value == 0 ? Color.clear : PlayerColors.lightColor(for: player.colorIndex))
        .animation(AppMotion.state, value: value == 0)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(player.name), total score \(totalScore), round score \(value)")
    }

    private var playerIdentity: some View {
        HStack(spacing: AppTheme.spacingSmall) {
            BauhausPlayerShape(colorIndex: player.colorIndex, size: 38)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    PlayerGlyph(colorIndex: player.colorIndex, font: AppFonts.caption)

                    Text(player.name)
                        .font(AppFonts.body)
                        .foregroundStyle(ClubhouseTheme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .layoutPriority(1)

                    if isLeading {
                        BrassCrown()
                            .fixedSize()
                            .accessibilityLabel("Leading")
                    }
                }
                .layoutPriority(1)

                Text("Round points")
                    .font(AppFonts.caption)
                    .foregroundStyle(ClubhouseTheme.inkMuted)
            }
            .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .layoutPriority(2)
    }

    private var totalColumn: some View {
        Text("\(totalScore)")
            .font(AppFonts.scoreSmall)
            .monospacedDigit()
            .foregroundStyle(isLeading ? ClubhouseTheme.brass : ClubhouseTheme.ink)
            .contentTransition(.numericText(value: Double(totalScore)))
        .frame(width: 64, alignment: .trailing)
    }

    private var scoreStepper: some View {
        CompactScoreStepper(value: $value, range: range, step: step, identifierPrefix: identifierPrefix)
            .frame(width: 160, alignment: .trailing)
    }

    @ViewBuilder
    private var quickButtons: some View {
        ForEach(quickAmounts, id: \.self) { amount in
            quickButton(amount)
        }
    }

    private func quickButton(_ amount: Int) -> some View {
        Button("+\(amount)") {
            apply(amount)
        }
        .font(AppFonts.caption)
        .monospacedDigit()
        .foregroundStyle(ClubhouseTheme.ink)
        .padding(.horizontal, 9)
        .frame(minHeight: 30)
        .background(ClubhouseTheme.paperSunken, in: RoundedRectangle(cornerRadius: 5))
        .overlay { RoundedRectangle(cornerRadius: 5).strokeBorder(ClubhouseTheme.ruleStrong, lineWidth: 1) }
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

private struct CompactScoreStepper: View {
    @Binding var value: Int
    var range: ClosedRange<Int>
    var step: Int
    var identifierPrefix: String

    var body: some View {
        HStack(spacing: 6) {
            stepButton(systemImage: "minus", delta: -step, identifier: "decrement", label: "Decrease score")

            VStack(spacing: 0) {
                Text("RD")
                    .font(AppFonts.caption)
                    .foregroundStyle(ClubhouseTheme.inkMuted)

                Text(roundScoreText)
                    .font(AppFonts.scoreSmall)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .contentTransition(.numericText(value: Double(value)))
                    .foregroundStyle(ClubhouseTheme.ink)
            }
            .frame(width: 58)
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier(identifierPrefix + "score")
            .accessibilityLabel("Score \(value)")

            stepButton(systemImage: "plus", delta: step, identifier: "increment", label: "Increase score")
        }
    }

    private func stepButton(systemImage: String, delta: Int, identifier: String, label: String) -> some View {
        Button {
            apply(delta)
        } label: {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(systemImage == "plus" ? ClubhouseTheme.blue : ClubhouseTheme.red)
                .frame(width: 44, height: 44)
                .background(ClubhouseTheme.paperCard, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                        .strokeBorder(ClubhouseTheme.ruleStrong, lineWidth: 1.25)
                }
        }
        .buttonStyle(ClubhousePressableButtonStyle())
        .accessibilityIdentifier(identifierPrefix + identifier)
        .accessibilityLabel(label)
    }

    private func apply(_ delta: Int) {
        let newValue = value + delta
        if range.contains(newValue) {
            value = newValue
        }
    }

    private var roundScoreText: String {
        value >= 0 ? "+\(value)" : "\(value)"
    }
}
