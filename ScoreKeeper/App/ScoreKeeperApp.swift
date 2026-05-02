import SwiftUI
import SwiftData

@main
struct ScoreKeeperApp: App {
    @State private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(themeManager)
                .preferredColorScheme(themeManager.effectiveColorScheme)
        }
        .modelContainer(sharedModelContainer)
    }

    private var sharedModelContainer: ModelContainer {
        let schema = Schema([GameSession.self, Player.self, Round.self, ScoreEntry.self, SavedPlayer.self])
        let isUITesting = ProcessInfo.processInfo.arguments.contains("-in-memory-store")

        let configurations: [ModelConfiguration] = isUITesting
            ? [ModelConfiguration(isStoredInMemoryOnly: true)]
            : []

        guard let container = try? ModelContainer(for: schema, configurations: configurations) else {
            fatalError("Failed to create ModelContainer.")
        }
        return container
    }
}
