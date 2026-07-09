import SwiftUI
import SwiftData

struct ScoringView: View {
    let sessionID: PersistentIdentifier
    @Environment(\.modelContext) private var modelContext
    @Environment(NavigationRouter.self) private var router
    @Environment(ReviewPromptCoordinator.self) private var reviewPrompt
    @State private var showEndGameAlert = false
    @State private var completionError: String?

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
        .alert("Couldn’t Finish Game", isPresented: completionErrorBinding) {
            Button("OK", role: .cancel) { completionError = nil }
        } message: {
            Text(completionError ?? "Please try again.")
        }
        .navigationBarBackButtonHidden(true)
    }

    private var completionErrorBinding: Binding<Bool> {
        Binding(
            get: { completionError != nil },
            set: { if !$0 { completionError = nil } }
        )
    }

    private func endGame(_ session: GameSession, engine: GameEngine) {
        session.isComplete = true
        session.completedAt = .now
        let winnerIDs = engine.winners(session: session)
        session.winnerID = winnerIDs.first
        do {
            try modelContext.save()
            reviewPrompt.recordSuccessfulGame()
            router.push(.gameOver(session.persistentModelID))
        } catch {
            modelContext.rollback()
            completionError = "Your completed game couldn’t be saved. It is still open so you can try again."
        }
    }
}

// MARK: - Session Loader

struct SessionLoader<Content: View>: View {
    let sessionID: PersistentIdentifier
    @ViewBuilder let content: (GameSession) -> Content
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        if let session = fetchSession() {
            content(session)
        } else {
            ContentUnavailableView("Game Not Found", systemImage: "exclamationmark.triangle")
        }
    }

    private func fetchSession() -> GameSession? {
        let descriptor = FetchDescriptor<GameSession>(
            predicate: #Predicate<GameSession> { session in
                session.persistentModelID == sessionID
            }
        )

        return try? modelContext.fetch(descriptor).first
    }
}
