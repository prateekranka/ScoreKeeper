import SwiftData
import SwiftUI
import StoreKit

@main
struct ScoreKeeperApp: App {
    @UIApplicationDelegateAdaptor(PipCountAppDelegate.self) private var appDelegate
    @State private var themeManager = ThemeManager()
    @State private var storeManager = StoreManager()
    @State private var reviewAskManager = ReviewAskManager()
    @State private var containerResult = ScoreKeeperApp.makeModelContainer()

    var body: some Scene {
        WindowGroup {
            Group {
                if let container = containerResult.container {
                    PipCountRootView()
                        .environment(themeManager)
                        .environment(storeManager)
                        .environment(reviewAskManager)
                        .preferredColorScheme(themeManager.effectiveColorScheme)
                        .modelContainer(container)
                        #if DEBUG
                        .id(ObjectIdentifier(container))
                        .environment(\.pipCountDebugFixtures, BreakUIFixture.isEnabled ? PipCountDebugFixtures(
                            modes: BreakUIFixture.modes,
                            select: { mode in containerResult = ScoreKeeperApp.makeModelContainer(fixtureMode: mode) }
                        ) : nil)
                        #endif
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
    private static func makeModelContainer(fixtureMode: String = "demo") -> ModelContainerResult {
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
            #if DEBUG
            if BreakUIFixture.isEnabled {
                try BreakUIFixture.seed(container.mainContext, mode: fixtureMode)
            }
            #endif
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
                        .font(AppFonts.label)
                        .foregroundStyle(ClubhouseTheme.red)
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
                    .font(AppFonts.label)
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

private struct PipCountRootView: View {
    @State private var router = NavigationRouter()

    var body: some View {
        ContentView(router: router)
    }
}

#if DEBUG
@MainActor
private enum BreakUIFixture {
    static let modes = ["demo", "worst", "empty", "one", "huge"]
    static var isEnabled: Bool {
        let args = ProcessInfo.processInfo.arguments
        return args.contains("-break-ui-data") && args.contains("-in-memory-store")
    }
    static let names = [
        "Aleksandra Wiśniewska-Kowalczyk", "Christopher Alexander Montgomery III",
        "Konstantin Oberhauser-Wettstein", "Jo", "J", "Ólafur Darri Ólafsson",
        "Đặng Thị Ngọc Hân", "王秀英", "نور الهدى عبد الرحمن",
        "Seán O'Brien-Ó Súilleabháin", "María José de la Cruz y Fernández",
        "dana", "🦊 Fox", "👩🏽‍💻 Priya", "Ferdinand-Habsburg-Lothringen"
    ].map { $0.lowercased() }

    static func seed(_ context: ModelContext, mode: String) throws {
        guard mode != "empty" else { return }
        let roster: [String]
        switch mode {
        case "worst": roster = names + [""]
        case "one": roster = ["jo"]
        case "huge": roster = (0..<1284).map { names[$0 % names.count] + " \($0 + 1)" }
        default: roster = ["maya", "leo"]
        }
        for (index, name) in roster.enumerated() {
            let player = SavedPlayer(name: name, colorIndex: index % PlayerColors.palette.count)
            player.lastUsed = Date(timeIntervalSince1970: 1_760_000_000 - Double(index * 60))
            context.insert(player)
        }
        let gameCount = mode == "huge" ? 1284 : 1
        for index in 0..<gameCount {
            let session = GameSession(gameType: .generic)
            session.createdAt = Date(timeIntervalSince1970: 1_760_000_000 - Double(index * 86400))
            session.isComplete = mode == "one" || mode == "huge"
            session.completedAt = session.isComplete ? session.createdAt.addingTimeInterval(3600) : nil
            session.targetScore = mode == "worst" ? 1_000_000 : nil
            let gameNames = mode == "worst" ? names : [roster[index % roster.count], "leo"]
            context.insert(session)
            for (color, name) in gameNames.enumerated() {
                let player = Player(name: name, colorIndex: color % PlayerColors.palette.count)
                player.session = session
                session.players.append(player)
                context.insert(player)
            }
            let roundCount = mode == "worst" ? 50 : 1
            for number in 1...roundCount {
                let round = Round(roundNumber: number)
                round.createdAt = session.createdAt.addingTimeInterval(Double(number * 60))
                round.session = session
                session.rounds.append(round)
                context.insert(round)
                for (position, player) in session.players.enumerated() {
                    let points = mode == "worst" ? [99, 0, 1][position % 3] : [7, 9][position % 2]
                    let entry = ScoreEntry(playerID: player.id, points: points)
                    entry.round = round
                    round.entries.append(entry)
                    context.insert(entry)
                }
            }
            if session.isComplete {
                session.winnerID = session.players.max { $0.totalScore(in: session) < $1.totalScore(in: session) }?.id
            }
        }
        try context.save()
    }
}
#endif
