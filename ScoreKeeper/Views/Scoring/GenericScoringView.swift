import SwiftUI
import SwiftData

struct GenericScoringView: View {
    @Bindable var session: GameSession
    @Environment(\.modelContext) private var modelContext
    @Environment(NavigationRouter.self) private var router
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
        .fullScreenCover(isPresented: $showDeck, onDismiss: routeToGameOverIfComplete) {
            RoundEntryDeckView(
                session: session,
                onSubmit: { roundScores in
                    submitRound(using: roundScores)
                },
                onCancel: { showDeck = false }
            )
        }
        .task { reconcileOnResume() }
        .sensoryFeedback(.impact, trigger: scoreHapticTrigger)
        .alert("couldn’t save game", isPresented: Binding(
            get: { saveError != nil }, set: { if !$0 { saveError = nil } }
        )) {
            Button("try again") {
                saveError = nil
                reconcileOnResume()
            }
            Button("ok", role: .cancel) { saveError = nil }
        } message: { Text(saveError ?? "please try again") }
    }

    /// Returns nil after a successful save (the deck then dismisses); returns
    /// a user-facing message when the round cannot be saved, so the deck can
    /// stay open with the confirmed scores intact (PC17-003).
    private func submitRound(using roundScores: [UUID: Int]) -> String? {
        do {
            try GenericRoundPersistence.submit(session: session, scores: roundScores, context: modelContext) { context in
                #if DEBUG
                try RoundSaveFailureSeam.throwIfArmed()
                #endif
                try context.save()
            }
        } catch {
            return error.localizedDescription
        }
        showDeck = false
        scoreHapticTrigger += 1
        return nil
    }

    private func reconcileOnResume() {
        guard !didRouteToGameOver else { return }
        do {
            try GenericRoundPersistence.reconcile(session: session, context: modelContext)
            routeToGameOverIfComplete()
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func routeToGameOverIfComplete() {
        guard session.isComplete, !showDeck, !didRouteToGameOver else { return }
        didRouteToGameOver = true
        router.push(.gameOver(session.persistentModelID))
    }
}

@MainActor
enum GenericRoundPersistence {
    static func submit(
        session: GameSession,
        scores: [UUID: Int],
        context: ModelContext,
        save: (ModelContext) throws -> Void = { try $0.save() }
    ) throws {
        guard session.gameType == .generic, !session.isComplete else {
            throw NSError(domain: "RoundPersistence", code: 1, userInfo: [NSLocalizedDescriptionKey: "this game is already complete or is not a scoreboard game"])
        }
        guard !session.players.isEmpty, session.players.allSatisfy({ scores[$0.id] != nil }) else {
            throw NSError(domain: "RoundPersistence", code: 2, userInfo: [NSLocalizedDescriptionKey: "every player needs a confirmed score before this round can save"])
        }
        let autosaveEnabled = context.autosaveEnabled
        context.autosaveEnabled = false
        defer { context.autosaveEnabled = autosaveEnabled }
        let originalRounds = session.rounds
        let completion = (session.isComplete, session.completedAt, session.winnerID)
        let round = Round(roundNumber: session.currentRoundNumber)
        round.entries = session.players.map { player in
            ScoreEntry(playerID: player.id, points: scores[player.id]!)
        }
        context.insert(round)
        round.session = session
        session.rounds = originalRounds + [round]
        completeIfQualified(session)
        do {
            try save(context)
        } catch {
            session.isComplete = completion.0
            session.completedAt = completion.1
            session.winnerID = completion.2
            session.rounds = originalRounds
            round.session = nil
            for entry in round.entries { context.delete(entry) }
            context.delete(round)
            throw error
        }
    }

    static func reconcile(
        session: GameSession,
        context: ModelContext,
        save: (ModelContext) throws -> Void = { try $0.save() }
    ) throws {
        guard session.gameType == .generic, !session.isComplete, GenericEngine().isGameOver(session: session) else { return }
        let autosaveEnabled = context.autosaveEnabled
        context.autosaveEnabled = false
        defer { context.autosaveEnabled = autosaveEnabled }
        let completion = (session.isComplete, session.completedAt, session.winnerID)
        completeIfQualified(session)
        do {
            try save(context)
        } catch {
            session.isComplete = completion.0
            session.completedAt = completion.1
            session.winnerID = completion.2
            throw error
        }
    }

    private static func completeIfQualified(_ session: GameSession) {
        guard GenericEngine().isGameOver(session: session) else { return }
        session.isComplete = true
        session.completedAt = session.completedAt ?? session.sortedRounds.last?.createdAt
        session.winnerID = GenericEngine().winners(session: session).first
    }
}

private struct GenericTotalsList: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let session: GameSession
    let engine: GameEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: AppTheme.spacingSmall))
                : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
            layout {
                VStack(alignment: .leading, spacing: 2) {
                    Text("running totals").font(AppFonts.title).foregroundStyle(ClubhouseTheme.ink)
.font(AppFonts.label).foregroundStyle(ClubhouseTheme.inkMuted)
                }
                if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                Text(session.winCondition == .highestScore ? "highest wins" : "lowest wins")
                    .columnHeaderStyle().foregroundStyle(ClubhouseTheme.blue)
            }
            .padding(AppTheme.spacingMedium)
            Rectangle().fill(ClubhouseTheme.rule).frame(height: 1)
            ForEach(Array(session.players.enumerated()), id: \.element.id) { index, player in
                let lastEntry = session.sortedRounds.last?.entries.first(where: { $0.playerID == player.id })
                layout {
                    BauhausPlayerShape(colorIndex: player.colorIndex, size: 34)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(player.name).font(AppFonts.headline).foregroundStyle(ClubhouseTheme.ink)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(lastRoundText(lastEntry))
                            .font(AppFonts.label).foregroundStyle(ClubhouseTheme.inkMuted).monospacedDigit()
                    }
                    if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                    Text("\(player.totalScore(in: session))").font(AppFonts.scoreMedium).monospacedDigit().foregroundStyle(ClubhouseTheme.ink)
                        .accessibilityIdentifier("running_total_\(player.name)")
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

    /// A submitted zero is a score: show it. Only a round that has no entry
    /// for this player reads as absent.
    private func lastRoundText(_ entry: ScoreEntry?) -> String {
        guard let entry else { return "no score last round" }
        return "last round \(entry.points > 0 ? "+\(entry.points)" : "\(entry.points)")"
    }
}

#if DEBUG
/// UI-test seam: launching with `-fail-first-round-save` makes the next
/// round save fail exactly once, so the deck's draft-retention path can be
/// exercised on a disposable simulator. It is compiled out of release
/// builds and never touches a real save path unless the argument is present.
@MainActor
enum RoundSaveFailureSeam {
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
