import SwiftUI
import SwiftData

struct ScoringView: View {
    let sessionID: PersistentIdentifier
    @Environment(\.modelContext) private var modelContext
    @Environment(NavigationRouter.self) private var router
    @State private var showEndGameAlert = false
    @State private var saveError: String?

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
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    router.goHome()
                } label: {
                    Image(systemName: "house")
                }
                .accessibilityLabel("Home")
                .accessibilityIdentifier("scoring_home_button")
                .foregroundStyle(ClubhouseTheme.ink)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button("end game") {
                    showEndGameAlert = true
                }
                .accessibilityIdentifier("end_game_button")
                .font(AppFonts.body)
                .foregroundStyle(ClubhouseTheme.lacquer)
            }
        }
        .alert("end game?", isPresented: $showEndGameAlert) {
            Button("cancel", role: .cancel) {}
            Button("end game", role: .destructive) {
                endGame(session, engine: engine)
            }
        } message: {
            Text("this will finish the current game and determine the winner")
        }
        .alert(
            "couldn’t save game",
            isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )
        ) {
            Button("ok", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "please try again")
        }
        .navigationBarBackButtonHidden(true)
    }

    private func endGame(_ session: GameSession, engine: GameEngine) {
        session.isComplete = true
        session.completedAt = .now
        let winnerIDs = engine.winners(session: session)
        session.winnerID = winnerIDs.first
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
