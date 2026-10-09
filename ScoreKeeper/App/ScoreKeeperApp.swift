import SwiftData
import SwiftUI
import StoreKit

@main
struct ScoreKeeperApp: App {
    @State private var themeManager = ThemeManager()
    @State private var storeManager = StoreManager()
    @State private var reviewAskManager = ReviewAskManager()
    @State private var containerResult = ScoreKeeperApp.makeModelContainer()

    var body: some Scene {
        WindowGroup {
            Group {
                if let container = containerResult.container {
                    AdaptivePipCountRootView()
                        .environment(themeManager)
                        .environment(storeManager)
                        .environment(reviewAskManager)
                        .preferredColorScheme(themeManager.effectiveColorScheme)
                        .modelContainer(container)
                } else {
                    StartupRecoveryView(message: containerResult.message) {
                        containerResult = ScoreKeeperApp.makeModelContainer()
                    }
                    .preferredColorScheme(themeManager.effectiveColorScheme)
                }
            }
        }
    }

    private struct ModelContainerResult {
        let container: ModelContainer?
        let message: String?
    }

    /// Opening the store is fallible. A failure keeps the underlying error
    /// and shows the recovery screen instead of aborting at launch; the
    /// user's data is never deleted, replaced, or moved to an empty store, so
    /// a retry (or a restart) opens the same store again.
    private static func makeModelContainer() -> ModelContainerResult {
        #if DEBUG
        if consumeForcedStoreOpenFailureIfArmed() {
            return ModelContainerResult(
                container: nil,
                message: "simulated store open failure (ui-test seam)"
            )
        }
        #endif

        let schema = Schema([GameSession.self, Player.self, Round.self, ScoreEntry.self, SavedPlayer.self])
        let isUITesting = ProcessInfo.processInfo.arguments.contains("-in-memory-store")

        let configurations: [ModelConfiguration] = isUITesting
            ? [ModelConfiguration(isStoredInMemoryOnly: true)]
            : []

        do {
            let container = try ModelContainer(for: schema, configurations: configurations)
            return ModelContainerResult(container: container, message: nil)
        } catch {
            return ModelContainerResult(container: nil, message: error.localizedDescription)
        }
    }

    #if DEBUG
    /// UI-test seam: launching with `-force-store-open-failure-once` makes the
    /// first store open fail; the retry in the same launch succeeds. Compiled
    /// out of release builds and never touches a real store.
    nonisolated(unsafe) private static var forcedStoreOpenFailuresRemaining =
        ProcessInfo.processInfo.arguments.contains("-force-store-open-failure-once") ? 1 : 0

    private static func consumeForcedStoreOpenFailureIfArmed() -> Bool {
        guard forcedStoreOpenFailuresRemaining > 0 else { return false }
        forcedStoreOpenFailuresRemaining -= 1
        return true
    }
    #endif
}

/// Shown when the SwiftData store cannot open. The app never deletes or
/// replaces the user's data on its own; Try Again re-attempts the same store.
private struct StartupRecoveryView: View {
    let message: String?
    let retry: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacingLarge) {
                PipCountGeometricArtwork(scene: .homeEmpty)
                    .frame(maxWidth: 320)
                    .frame(height: 230)

                VStack(spacing: AppTheme.spacingSmall) {
                    Text("couldn’t open your saved games")
                        .font(AppFonts.hero)
                        .foregroundStyle(ClubhouseTheme.ink)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("pipcount keeps your history on this device. the library did not open, and nothing was changed. try again in a moment.")
                        .font(AppFonts.body)
                        .foregroundStyle(ClubhouseTheme.inkMuted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let message {
                    Text(message)
                        .font(AppFonts.caption)
                        .foregroundStyle(ClubhouseTheme.lacquer)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                AppActionButton(role: .primary(ClubhouseTheme.blue)) {
                    retry()
                } label: {
                    Label("try again", systemImage: "arrow.clockwise")
                }
                .accessibilityIdentifier("startup_retry_button")
                .frame(maxWidth: 420)

                Text("if this keeps happening, restart the app. your saved games stay on this device.")
                    .font(AppFonts.caption)
                    .foregroundStyle(ClubhouseTheme.inkMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(AppTheme.spacingXLarge)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .appBackground()
        .accessibilityIdentifier("startup_recovery_view")
    }
}

/// iPhone keeps the focused bottom-dock flow. Once onboarding is complete,
/// regular-width iPads move into a persistent two-column application shell.
///
/// The shell only changes at a state-neutral point (the home route): crossing
/// the size-class breakpoint mid-flow keeps the active shell, so the current
/// route, entered values, and a presented deck survive the resize (PC17-008).
private struct AdaptivePipCountRootView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var router = NavigationRouter()
    @State private var shellIsTablet: Bool?

    var body: some View {
        Group {
            if resolvedShellIsTablet {
                PipCountTabletRootView(router: router)
            } else {
                ContentView(router: router)
            }
        }
        .onAppear { commitInitialShell() }
        .onChange(of: horizontalSizeClass) { _, _ in resolveShell() }
        .onChange(of: hasCompletedOnboarding) { _, _ in resolveShell() }
        .onChange(of: router.path.count) { _, _ in resolveShell() }
        .onChange(of: router.isPageExiting) { _, _ in resolveShell() }
    }

    /// Before the first commit, render the shell the environment asks for so
    /// there is no one-frame flash.
    private var resolvedShellIsTablet: Bool {
        shellIsTablet ?? wantsTabletShell
    }

    private func commitInitialShell() {
        guard shellIsTablet == nil else { return }
        shellIsTablet = wantsTabletShell
    }

    private func resolveShell() {
        let wantsTablet = wantsTabletShell
        guard let current = shellIsTablet else {
            shellIsTablet = wantsTablet
            return
        }
        guard wantsTablet != current else { return }

        // Swap only when no flow is active: a resize mid-game must not throw
        // away the route, entered values, the active game, or a presented deck.
        guard router.path.isEmpty, !router.isPageExiting else { return }
        shellIsTablet = wantsTablet
    }

    private var wantsTabletShell: Bool {
        guard horizontalSizeClass == .regular else { return false }

        let arguments = ProcessInfo.processInfo.arguments
        let resetsOnboarding = arguments.contains("-reset-onboarding")
        let skipsOnboardingForTests = arguments.contains("-in-memory-store") && !resetsOnboarding
        return hasCompletedOnboarding || skipsOnboardingForTests
    }
}

private struct PipCountTabletRootView: View {
    @Bindable var router: NavigationRouter

    @Environment(ReviewAskManager.self) private var reviewAskManager
    @Environment(\.requestReview) private var requestReview
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var containerWidth: CGFloat = 0

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            PipCountSidebar(selected: router.selectedTab, onSelect: selectTab)
                .navigationSplitViewColumnWidth(min: 248, ideal: 292, max: 330)
        } detail: {
            PipCountNavigationRoot(tab: router.selectedTab, router: router)
                .id(router.selectedTab)
        }
        .navigationSplitViewStyle(.balanced)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { width in
            containerWidth = width
            columnVisibility = width >= 760 ? .all : .detailOnly
        }
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
        router.selectedTab = tab
        if containerWidth < 760 { columnVisibility = .detailOnly }
    }
}
