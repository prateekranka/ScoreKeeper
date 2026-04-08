import SwiftUI
import SwiftData

struct ScoringView: View {
    let sessionID: PersistentIdentifier
    @Environment(\.modelContext) private var modelContext
    @Environment(NavigationRouter.self) private var router
    @State private var showEndGameAlert = false

    var body: some View {
        SessionLoader(sessionID: sessionID) { session in
            scoringContent(session)
        }
    }

    @ViewBuilder
    private func scoringContent(_ session: GameSession) -> some View {
        let engine = GameEngineFactory.engine(for: session.gameType)

        VStack(spacing: 0) {
            // Scoreboard header
            scoreboardHeader(session, engine: engine)

            Divider()

            // Game-specific scoring view
            switch session.gameType {
            case .generic:
                GenericScoringView(session: session)
            case .whatsForDinner:
                WhatsForDinnerScoringView(session: session)
            case .phase10:
                Phase10ScoringView(session: session)
            }
        }
        .appBackground()
        .navigationTitle(session.gameType.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("End Game") {
                    showEndGameAlert = true
                }
                .font(AppFonts.body)
                .foregroundStyle(.red)
            }
        }
        .alert("End Game?", isPresented: $showEndGameAlert) {
            Button("Cancel", role: .cancel) {}
            Button("End Game", role: .destructive) {
                endGame(session, engine: engine)
            }
        } message: {
            Text("This will finish the current game and determine the winner.")
        }
        .navigationBarBackButtonHidden(true)
    }

    private func scoreboardHeader(_ session: GameSession, engine: GameEngine) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppTheme.spacingSmall) {
                ForEach(session.players, id: \.id) { player in
                    let score = engine.totalScore(for:
                        session.rounds.flatMap(\.entries).filter { $0.playerID == player.id }
                    )
                    let winners = engine.winners(session: session)
                    ScoreCard(
                        player: player,
                        totalScore: score,
                        isLeading: winners.contains(player.id) && session.rounds.count > 0
                    )
                }
            }
            .padding(AppTheme.spacingMedium)
        }
    }

    private func endGame(_ session: GameSession, engine: GameEngine) {
        session.isComplete = true
        session.completedAt = Date()
        let winnerIDs = engine.winners(session: session)
        session.winnerID = winnerIDs.first
        try? modelContext.save()
        router.push(.gameOver(session.persistentModelID))
    }
}

// MARK: - Session Loader

struct SessionLoader<Content: View>: View {
    let sessionID: PersistentIdentifier
    @ViewBuilder let content: (GameSession) -> Content
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        if let session = modelContext.model(for: sessionID) as? GameSession {
            content(session)
        } else {
            ContentUnavailableView("Game Not Found", systemImage: "exclamationmark.triangle")
        }
    }
}
