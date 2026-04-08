import SwiftUI
import SwiftData

@Observable
class NavigationRouter {
    var path = NavigationPath()

    func goHome() {
        path = NavigationPath()
    }

    func push(_ destination: AppDestination) {
        path.append(destination)
    }

    func pop() {
        if !path.isEmpty {
            path.removeLast()
        }
    }
}

enum AppDestination: Hashable {
    case gamePicker
    case playerSetup(GameType)
    case gameConfig(GameType, [String])
    case scoring(PersistentIdentifier)
    case gameOver(PersistentIdentifier)
    case gameDetail(PersistentIdentifier)
    case gameHistory
}

struct ContentView: View {
    @State private var router = NavigationRouter()

    var body: some View {
        NavigationStack(path: $router.path) {
            HomeView()
                .navigationDestination(for: AppDestination.self) { destination in
                    switch destination {
                    case .gamePicker:
                        GamePickerView()
                    case .playerSetup(let gameType):
                        PlayerSetupView(gameType: gameType)
                    case .gameConfig(let gameType, let playerNames):
                        GameConfigView(gameType: gameType, playerNames: playerNames)
                    case .scoring(let sessionID):
                        ScoringView(sessionID: sessionID)
                    case .gameOver(let sessionID):
                        GameOverView(sessionID: sessionID)
                    case .gameDetail(let sessionID):
                        GameDetailView(sessionID: sessionID)
                    case .gameHistory:
                        GameHistoryListView()
                    }
                }
        }
        .environment(router)
    }
}
