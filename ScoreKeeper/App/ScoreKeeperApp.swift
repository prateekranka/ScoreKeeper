import SwiftUI
import SwiftData

@main
struct ScoreKeeperApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            GameSession.self,
            Player.self,
            Round.self,
            ScoreEntry.self
        ])
    }
}
