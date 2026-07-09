import SwiftUI
import SwiftData

struct ScoringView: View {
    let sessionID: PersistentIdentifier
    @Environment(\.modelContext) private var modelContext
    @Environment(NavigationRouter.self) private var router
    @Environment(StoreManager.self) private var storeManager
    @Environment(ReviewAskManager.self) private var reviewAskManager
    @State private var showEndGameAlert = false

    var body: some View {
        SessionLoader(sessionID: sessionID) { session in
            scoringContent(session)
        }
    }

    @ViewBuilder
    private func scoringContent(_ session: GameSession) -> some View {
        let engine = GameEngineFactory.engine(for: session.gameType)

        Group {
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
                .accessibilityIdentifier("end_game_button")
                .font(AppFonts.body)
                .foregroundStyle(ClubhouseTheme.lacquer)
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

    private func endGame(_ session: GameSession, engine: GameEngine) {
        session.isComplete = true
        session.completedAt = .now
        let winnerIDs = engine.winners(session: session)
        session.winnerID = winnerIDs.first
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
