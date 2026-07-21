import SwiftUI
import SwiftData

@main
struct ScoreKeeperApp: App {
    @State private var themeManager = ThemeManager()
    @State private var storeManager = StoreManager()
    @State private var reviewAskManager = ReviewAskManager()
    private let modelContainer = ScoreKeeperApp.makeModelContainer()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(themeManager)
                .environment(storeManager)
                .environment(reviewAskManager)
                .preferredColorScheme(themeManager.effectiveColorScheme)
                .tuningPanel()
        }
        .modelContainer(modelContainer)
    }

    private static func makeModelContainer() -> ModelContainer {
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
