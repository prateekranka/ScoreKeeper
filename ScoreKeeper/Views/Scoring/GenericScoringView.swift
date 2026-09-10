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
    @State private var showDeck = false

    private let engine = GenericEngine()

    var body: some View {
        ScoringScreenLayout(
            session: session,
            engine: engine,
            actionTitle: "score round",
            actionSystemImage: "pencil.line",
            showsScoreboardHeader: false,
            headerStyle: .compact,
            showsToolsBar: false,
            action: { showDeck = true }
        ) {
            GenericTotalsList(session: session, engine: engine)
        } footer: {
            RoundHistoryStrip(session: session)
        }
        .fullScreenCover(isPresented: $showDeck) {
            RoundEntryDeckView(
                session: session,
                onSubmit: { roundScores in
                    submitRound(using: roundScores)
                },
                onCancel: { showDeck = false }
            )
        }
        .sensoryFeedback(.impact, trigger: scoreHapticTrigger)
        .alert("couldn’t save round", isPresented: Binding(
            get: { saveError != nil }, set: { if !$0 { saveError = nil } }
        )) {
            Button("ok", role: .cancel) { saveError = nil }
        } message: { Text(saveError ?? "please try again") }
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
            let entry = ScoreEntry(playerID: player.id, points: points)
            entry.round = round
            round.entries.append(entry)
        }
        session.rounds.append(round)
        do {
            #if DEBUG
            try RoundSaveFailureSeam.throwIfArmed()
            #endif
            try modelContext.save()
        } catch {
            let message = error.localizedDescription
            modelContext.rollback()
            return message
        }
        showDeck = false
        scores = [:]
        scoreHapticTrigger += 1
        if engine.isGameOver(session: session) { finishGame() }
        return nil
    }

    private func finishGame() {
        guard !didRouteToGameOver else { return }
        session.isComplete = true
        session.completedAt = .now
        session.winnerID = engine.winners(session: session).first
        do {
            try modelContext.save()
        } catch {
            saveError = error.localizedDescription
            modelContext.rollback()
            return
        }
        didRouteToGameOver = true
        router.push(.gameOver(session.persistentModelID))
    }
}

private struct GenericTotalsList: View {
    let session: GameSession
    let engine: GameEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("running totals").font(AppFonts.title).foregroundStyle(ClubhouseTheme.ink)
                    Text("add this round with handwriting").font(AppFonts.caption).foregroundStyle(ClubhouseTheme.inkMuted)
                }
                Spacer()
                Text(session.winCondition == .highestScore ? "highest wins" : "lowest wins")
                    .columnHeaderStyle().foregroundStyle(ClubhouseTheme.blue)
            }
            .padding(AppTheme.spacingMedium)
            Rectangle().fill(ClubhouseTheme.rule).frame(height: 1)
            ForEach(Array(session.players.enumerated()), id: \.element.id) { index, player in
                let lastRound = session.sortedRounds.last?.entries.first(where: { $0.playerID == player.id })?.points ?? 0
                HStack(spacing: AppTheme.spacingSmall) {
                    BauhausPlayerShape(colorIndex: player.colorIndex, size: 34)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(player.name).font(AppFonts.headline).foregroundStyle(ClubhouseTheme.ink).lineLimit(1)
                        Text(lastRound == 0 ? "no score last round" : "last round \(lastRound > 0 ? "+\(lastRound)" : "\(lastRound)")")
                            .font(AppFonts.caption).foregroundStyle(ClubhouseTheme.inkMuted).monospacedDigit()
                    }
                    Spacer()
                    Text("\(player.totalScore(in: session))").font(AppFonts.scoreMedium).monospacedDigit().foregroundStyle(ClubhouseTheme.ink)
                }
                .padding(.horizontal, AppTheme.spacingMedium)
                .padding(.vertical, 10)
                if index < session.players.count - 1 { Rectangle().fill(ClubhouseTheme.rule).frame(height: 1).padding(.leading, 60) }
            }
        }
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge, isInteractive: true)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Round \(session.currentRoundNumber) running totals")
    }
}

#if DEBUG
/// UI-test seam: launching with `-fail-first-round-save` makes the next
/// round save fail exactly once, so the deck's draft-retention path can be
/// exercised on a disposable simulator. It is compiled out of release
/// builds and never touches a real save path unless the argument is present.
@MainActor
private enum RoundSaveFailureSeam {
    private static var remainingFailures = ProcessInfo.processInfo.arguments.contains("-fail-first-round-save") ? 1 : 0

    static func throwIfArmed() throws {
        guard remainingFailures > 0 else { return }
        remainingFailures -= 1
        throw NSError(
            domain: "PipCountTestSeam",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "simulated save failure (ui-test seam)"]
        )
    }
}
#endif
