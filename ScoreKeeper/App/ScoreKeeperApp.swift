import SwiftData
import SwiftUI

@main
struct ScoreKeeperApp: App {
    @State private var themeManager = ThemeManager()
    @State private var storeManager = StoreManager()
    @State private var reviewAskManager = ReviewAskManager()
    private let modelContainer = ScoreKeeperApp.makeModelContainer()

    var body: some Scene {
        WindowGroup {
            AdaptivePipCountRootView()
                .environment(themeManager)
                .environment(storeManager)
                .environment(reviewAskManager)
                .preferredColorScheme(themeManager.effectiveColorScheme)
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

/// iPhone keeps the focused bottom-dock flow. Once onboarding is complete,
/// regular-width iPads move into a persistent two-column application shell.
private struct AdaptivePipCountRootView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        Group {
            if shouldUseTabletShell {
                PipCountTabletRootView()
            } else {
                ContentView()
            }
        }
    }

    private var shouldUseTabletShell: Bool {
        guard horizontalSizeClass == .regular else { return false }

        let arguments = ProcessInfo.processInfo.arguments
        let resetsOnboarding = arguments.contains("-reset-onboarding")
        let skipsOnboardingForTests = arguments.contains("-in-memory-store") && !resetsOnboarding
        return hasCompletedOnboarding || skipsOnboardingForTests
    }
}

private struct PipCountTabletRootView: View {
    @Environment(ReviewAskManager.self) private var reviewAskManager
    @Environment(\.requestReview) private var requestReview
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var router = NavigationRouter()
    @State private var selectedTab: PipCountTab = .home
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            PipCountSidebar(selected: selectedTab, onSelect: selectTab)
                .navigationSplitViewColumnWidth(min: 248, ideal: 292, max: 330)
        } detail: {
            NavigationStack(path: $router.path) {
                TabletHomeRoot {
                    selectedTab = .home
                }
                .navigationDestination(for: AppDestination.self, destination: destinationView)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .environment(router)
        .environment(\.pipCountPageIsExiting, router.isPageExiting)
        .onChange(of: reviewAskManager.reviewRequestPending) { _, isPending in
            guard isPending else { return }
            reviewAskManager.consumeReviewRequest()
            requestReview()
        }
        .onChange(of: reduceMotion) { _, newValue in
            router.configure(reduceMotion: newValue)
        }
        .onAppear {
            router.configure(reduceMotion: reduceMotion)
        }
    }

    private func selectTab(_ tab: PipCountTab) {
        selectedTab = tab

        switch tab {
        case .home:
            router.goHome()
        case .games:
            router.goHome()
            router.push(.gamePicker)
        case .players:
            router.goHome()
            router.push(.players)
        case .more:
            router.goHome()
            router.push(.legalSupport)
        }
    }

    @ViewBuilder
    private func destinationView(_ destination: AppDestination) -> some View {
        switch destination {
        case .gamePicker:
            GamePickerView()
        case .players:
            SavedPlayersView()
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
        case .headToHead:
            HeadToHeadView()
        case .playerStats(let playerName):
            PlayerStatsView(playerName: playerName)
        case .legalSupport:
            LegalSupportView()
        }
    }
}

private struct TabletHomeRoot: View {
    let didAppear: () -> Void

    var body: some View {
        HomeView()
            .onAppear(perform: didAppear)
    }
}
