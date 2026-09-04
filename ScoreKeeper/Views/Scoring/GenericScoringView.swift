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
                    showDeck = false
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

    private func submitRound(using roundScores: [UUID: Int]) {
        let round = Round(roundNumber: session.currentRoundNumber)
        round.session = session
        for player in session.players {
            let entry = ScoreEntry(playerID: player.id, points: roundScores[player.id] ?? 0)
            entry.round = round
            round.entries.append(entry)
        }
        session.rounds.append(round)
        do {
            try modelContext.save()
        } catch {
            saveError = error.localizedDescription
            modelContext.rollback()
            return
        }
        scores = [:]
        scoreHapticTrigger += 1
        if engine.isGameOver(session: session) { finishGame() }
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
