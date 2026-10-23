import SwiftUI
import UIKit
import SwiftData
import StoreKit
import Observation

@MainActor @Observable
class NavigationRouter {
    var selectedTab: PipCountTab = .home
    private var paths: [PipCountTab: NavigationPath] = [:]

    var path: NavigationPath {
        get { paths[selectedTab] ?? NavigationPath() }
        set { paths[selectedTab] = newValue }
    }

    func pathBinding(for tab: PipCountTab) -> Binding<NavigationPath> {
        Binding(
            get: { self.paths[tab] ?? NavigationPath() },
            set: { self.paths[tab] = $0 }
        )
    }
    var isPageExiting = false

    @ObservationIgnored private var reduceMotion = false
    @ObservationIgnored private var pendingMutations: [() -> Void] = []
    @ObservationIgnored private var transitionTask: Task<Void, Never>?

    func configure(reduceMotion: Bool) {
        self.reduceMotion = reduceMotion
    }

    func goHome() {
        transition {
            self.path = NavigationPath()
            self.selectedTab = .home
            self.path = NavigationPath()
        }
    }

    func push(_ destination: AppDestination) {
        transition {
            switch destination {
            case .gamePicker:
                self.selectedTab = .games
                self.path = NavigationPath()
            case .players:
                self.selectedTab = .players
                self.path = NavigationPath()
            case .legalSupport:
                self.selectedTab = .more
                self.path = NavigationPath()
            default:
                self.path.append(destination)
            }
        }
    }

    func pop() {
        guard !path.isEmpty else { return }
        transition {
            if !self.path.isEmpty {
                self.path.removeLast()
            }
        }
    }

    /// Allows multiple navigation operations issued by a single tap (for
    /// example go home, then open Players) to share one graceful art exit.
    private func transition(_ mutation: @escaping () -> Void) {
        if reduceMotion {
            mutation()
            return
        }

        pendingMutations.append(mutation)
        guard transitionTask == nil else { return }

        isPageExiting = true
        transitionTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(175))
            guard !Task.isCancelled, let self else { return }

            let mutations = self.pendingMutations
            self.pendingMutations.removeAll()

            withAnimation(AppMotion.page) {
                mutations.forEach { $0() }
            }

            self.isPageExiting = false
            self.transitionTask = nil
        }
    }
}

enum AppDestination: Hashable {
    case gamePicker
    case players
    case playerSetup(GameType)
    case gameConfig(GameType, [String])
    case scoring(PersistentIdentifier)
    case gameOver(PersistentIdentifier)
    case gameDetail(PersistentIdentifier)
    case gameHistory
    case headToHead
    case playerStats(String)
    case legalSupport
}

struct ContentView: View {
    @Bindable var router: NavigationRouter

    @Environment(ReviewAskManager.self) private var reviewAskManager
    @Environment(\.requestReview) private var requestReview
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var didApplyOnboardingReset = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        GeometryReader { proxy in
            let railInset = proxy.safeAreaInsets.trailing >= 60 && proxy.safeAreaInsets.leading <= 1
                ? proxy.safeAreaInsets.trailing : 0
            let usesIsland = horizontalSizeClass == .regular || railInset > 0
            TabView(selection: $router.selectedTab) {
                ForEach(PipCountTab.allCases, id: \.self) { tab in
                    PipCountNavigationRoot(tab: tab, router: router)
                        .background(NativeTabIdentifiers().frame(width: 0, height: 0))
                        .tabItem {
                            Label(tab.title, systemImage: tab.systemImage)
                                .accessibilityIdentifier(tab.accessibilityIdentifier)
                        }
                        .tag(tab)
                }
            }
            .tabViewStyle(.tabBarOnly)
            .ignoresSafeArea(.container, edges: railInset > 0 ? .trailing : [])
            .environment(\.pipCountUsesIsland, usesIsland)
            .environment(\.pipCountRailInset, railInset)
        }
        .appBackground()
        .tint(ClubhouseTheme.blue)
        .environment(router)
        .environment(\.pipCountPageIsExiting, router.isPageExiting)
        .fullScreenCover(isPresented: onboardingBinding) {
            OnboardingView {
                hasCompletedOnboarding = true
            }
            .environment(\.pipCountPageIsExiting, false)
        }
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
            resetOnboardingIfRequested()
        }
    }

    private var onboardingBinding: Binding<Bool> {
        Binding(
            get: { shouldShowOnboarding },
            set: { isPresented in
                if !isPresented {
                    hasCompletedOnboarding = true
                }
            }
        )
    }

    private var shouldShowOnboarding: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        let isOnboardingTest = arguments.contains("-reset-onboarding")
        return !hasCompletedOnboarding && (!arguments.contains("-in-memory-store") || isOnboardingTest)
    }

    private func resetOnboardingIfRequested() {
        guard !didApplyOnboardingReset,
              ProcessInfo.processInfo.arguments.contains("-reset-onboarding") else {
            return
        }

        didApplyOnboardingReset = true
        hasCompletedOnboarding = false
    }
}

/// SwiftUI does not forward tab-label identifiers to native tab items.
/// Set accessibility metadata through public UIKit APIs; leave rendering native.
private struct NativeTabIdentifiers: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller { Controller() }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.updateIdentifiers()
    }

    final class Controller: UIViewController {
        override func loadView() {
            view = UIView()
            view.isUserInteractionEnabled = false
            view.backgroundColor = .clear
        }

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            updateIdentifiers()
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            updateIdentifiers()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            updateIdentifiers()
        }

        override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
            super.viewWillTransition(to: size, with: coordinator)
            coordinator.animate(alongsideTransition: nil) { [weak self] _ in
                self?.updateIdentifiers()
            }
        }

        func updateIdentifiers() {
            var ancestor = parent
            while let controller = ancestor {
                if let tabs = controller as? UITabBarController,
                   let items = tabs.tabBar.items,
                   items.count == PipCountTab.allCases.count {
                    for (item, tab) in zip(items, PipCountTab.allCases) {
                        item.accessibilityIdentifier = tab.accessibilityIdentifier
                    }
                    return
                }
                ancestor = controller.parent
            }
        }
    }
}

struct PipCountNavigationRoot: View {
    let tab: PipCountTab
    @Bindable var router: NavigationRouter
    @Environment(\.pipCountUsesIsland) private var usesIsland
    @Environment(\.pipCountRailInset) private var railInset

    var body: some View {
        NavigationStack(path: router.pathBinding(for: tab)) {
            root
                .pipCountIsland {
                    ForEach(PipCountTab.allCases, id: \.self) { destination in
                        PipCountIslandButton(
                            title: destination.title,
                            systemImage: router.selectedTab == destination ? selectedSymbol(for: destination) : destination.systemImage,
                            identifier: destination.accessibilityIdentifier,
                            isSelected: router.selectedTab == destination
                        ) {
                            router.selectedTab = destination
                        }
                    }
                }
                .toolbarVisibility(usesIsland ? .hidden : .automatic, for: .tabBar)
                .toolbarVisibility(usesIsland || tab != .more ? .hidden : .automatic, for: .navigationBar)
                .navigationDestination(for: AppDestination.self) { destination in
                    destinationView(destination)
                        .pipCountIsland(isPresented: !destination.hasIslandActions) {
                            PipCountBackButton()
                        }
                        .toolbarVisibility(.hidden, for: .tabBar)
                        .toolbarVisibility(usesIsland || destination.hidesNavigationBar ? .hidden : .automatic, for: .navigationBar)
                }
        }
        .ignoresSafeArea(.container, edges: railInset > 0 ? .trailing : [])
        .appBackground()
    }

    private func selectedSymbol(for tab: PipCountTab) -> String {
        switch tab {
        case .home: "house.fill"
        case .games: "square.grid.2x2.fill"
        case .players: "person.2.fill"
        case .more: "ellipsis.circle.fill"
        }
    }

    @ViewBuilder
    private var root: some View {
        switch tab {
        case .home: HomeView()
        case .games: GamePickerView()
        case .players: SavedPlayersView()
        case .more: LegalSupportView()
        }
    }

    @ViewBuilder
    private func destinationView(_ destination: AppDestination) -> some View {
        switch destination {
        case .gamePicker: GamePickerView()
        case .players: SavedPlayersView()
        case .playerSetup(let gameType): PlayerSetupView(gameType: gameType)
        case .gameConfig(let gameType, let playerNames):
            GameConfigView(gameType: gameType, playerNames: playerNames)
        case .scoring(let sessionID): ScoringView(sessionID: sessionID)
        case .gameOver(let sessionID): GameOverView(sessionID: sessionID)
        case .gameDetail(let sessionID): GameDetailView(sessionID: sessionID)
        case .gameHistory: GameHistoryListView()
        case .headToHead: HeadToHeadView()
        case .playerStats(let playerName): PlayerStatsView(playerName: playerName)
        case .legalSupport: LegalSupportView()
        }
    }
}

private extension AppDestination {
    var hidesNavigationBar: Bool {
        if case .gameOver = self { return true }
        return false
    }

    var hasIslandActions: Bool {
        switch self {
        case .scoring, .gameOver, .gameDetail, .playerSetup, .gameConfig: true
        default: false
        }
    }
}

// MARK: - Onboarding

private struct OnboardingView: View {
    let finish: () -> Void
    @State private var selectedPage = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let pages = OnboardingPage.allCases

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("pipcount")
                    .font(AppFonts.title)
                    .foregroundStyle(ClubhouseTheme.ink)

                BauhausStarburst(color: ClubhouseTheme.blue, size: 19)

                Spacer()
            }
            .padding(.horizontal, AppTheme.spacingMedium)
            .padding(.top, AppTheme.spacingSmall)
            .pipCountPageContent()

            TabView(selection: $selectedPage) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                    OnboardingPageView(page: page, highlightsVisible: selectedPage == index)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack(spacing: AppTheme.spacingMedium) {
                OnboardingPageDots(count: pages.count, selectedPage: selectedPage)

                AppActionButton(role: .primary(ClubhouseTheme.felt), action: primaryAction) {
                    Label(
                        selectedPage == pages.count - 1 ? "start keeping score" : "continue",
                        systemImage: "arrow.right.circle.fill"
                    )
                }
                .accessibilityIdentifier("onboarding_primary_button")

                Button("skip", action: finish)
                    .font(AppFonts.body.weight(.semibold))
                    .foregroundStyle(ClubhouseTheme.ink)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityIdentifier("onboarding_skip_button")
            }
            .padding(AppTheme.spacingMedium)
            .appGlass(cornerRadius: AppTheme.cornerRadiusLarge, isInteractive: true)
            .padding(.horizontal, AppTheme.spacingMedium)
            .padding(.bottom, AppTheme.spacingSmall)
            .pipCountPageContent(maxWidth: AppTheme.formMaxWidth)
        }
        .appBackground()
    }

    private func primaryAction() {
        guard selectedPage < pages.count - 1 else {
            finish()
            return
        }

        withAnimation(reduceMotion ? AppMotion.fade : AppMotion.page) {
            selectedPage += 1
        }
    }
}

private struct OnboardingPageView: View {
    let page: OnboardingPage
    let highlightsVisible: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        ScrollView {
            Group {
                if horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize {
                    HStack(alignment: .center, spacing: AppTheme.spacingXXLarge) {
                        onboardingCopy
                            .frame(maxWidth: 360, alignment: .leading)

                        OnboardingArtwork(page: page, isVisible: highlightsVisible)
                            .frame(minHeight: 500)
                    }
                    .padding(.top, AppTheme.spacingLarge)
                } else {
                    VStack(alignment: .leading, spacing: AppTheme.spacingLarge) {
                        onboardingCopy

                        OnboardingArtwork(page: page, isVisible: highlightsVisible)
                            .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? 390 : 430)
                    }
                }
            }
            .padding(.horizontal, AppTheme.spacingMedium)
            .padding(.top, AppTheme.spacingMedium)
            .padding(.bottom, 132)
            .pipCountPageContent()
        }
        .accessibilityElement(children: .contain)
    }

    private var onboardingCopy: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            Text(page.title)
                .font(AppFonts.hero)
                .foregroundStyle(ClubhouseTheme.ink)
                .multilineTextAlignment(.leading)
                .accessibilityIdentifier("onboarding_page_title")
                .accessibilityHint(Text(page.accessibilityHint))

            Rectangle()
                .fill(page.tint)
                .frame(width: 82, height: 4)
                .padding(.top, 4)
        }
    }
}

private struct OnboardingArtwork: View {
    let page: OnboardingPage
    let isVisible: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                artworkBackdrop
                    .frame(width: proxy.size.width, height: proxy.size.height)

                artworkContent
                    .padding(AppTheme.spacingMedium)
                    .frame(maxWidth: min(proxy.size.width * 0.86, 470))
                    .background {
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                            .fill(ClubhouseTheme.paperCard.opacity(0.96))
                            .shadow(color: ClubhouseTheme.artShadow, radius: 18, y: 12)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                            .strokeBorder(ClubhouseTheme.ruleStrong, lineWidth: 1)
                    }
                    .rotationEffect(.degrees(page == .setupFast ? 1.4 : page == .toolsAndHistory ? -1.2 : 0))
                    .offset(y: proxy.size.height * 0.11)
            }
        }
        .frame(maxWidth: .infinity)
        .scaleEffect(isVisible || reduceMotion ? 1 : 0.965)
        .opacity(isVisible ? 1 : 0)
        .animation(reduceMotion ? AppMotion.fade : AppMotion.artEntrance, value: isVisible)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var artworkBackdrop: some View {
        switch page {
        case .scoreFast:
            PipCountGeometricArtwork(scene: .onboardingScore)
        case .setupFast:
            PipCountGeometricArtwork(scene: .onboardingSetup)
        case .toolsAndHistory:
            PipCountGeometricArtwork(scene: .onboardingHistory)
        }
    }

    @ViewBuilder
    private var artworkContent: some View {
        switch page {
        case .scoreFast:
            VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                HStack {
                    Text("round 4")
                        .columnHeaderStyle()
                    Spacer()
                    Text("live")
                        .columnHeaderStyle()
                        .foregroundStyle(ClubhouseTheme.red)
                }

                VStack(spacing: 0) {
                    LedgerRow(player: Player(name: "Mina", colorIndex: 0), score: 128, rank: 1, isLeader: true, isHighlighted: true)
                    LedgerRow(player: Player(name: "Omar", colorIndex: 1), score: 116, rank: 2)
                    LedgerRow(player: Player(name: "Jules", colorIndex: 3), score: 94, rank: 3)
                }

                HStack(spacing: AppTheme.spacingSmall) {
                    Text("Mina")
                        .columnHeaderStyle()
                    Spacer(minLength: AppTheme.spacingSmall)
                    OnboardingWritingMock()
                        .frame(width: 160, height: 48)
                }
            }
        case .setupFast:
            VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                HStack(spacing: AppTheme.spacingSmall) {
                    OnboardingGameCover(gameType: .generic, isSelected: true)
                    OnboardingGameCover(gameType: .phase10, isSelected: false)
                    OnboardingGameCover(gameType: .whatsForDinner, isSelected: false)
                }

                HStack {
                    Text("tonight's crew")
                        .columnHeaderStyle()
                    Spacer()
                    Text("saved")
                        .columnHeaderStyle()
                }

                VStack(spacing: 0) {
                    OnboardingRosterLine(name: "Mina", colorIndex: 0)
                    OnboardingRosterLine(name: "Omar", colorIndex: 1)
                    OnboardingRosterLine(name: "Jules", colorIndex: 3)
                }

                OnboardingPegStrip(currentPhase: 5)
            }
        case .toolsAndHistory:
            VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("final scores")
                            .columnHeaderStyle()

                    }

                    Spacer()

                    StampBadge(text: "final")
                }

                VStack(spacing: 0) {
                    LedgerRow(player: Player(name: "Mina", colorIndex: 0), score: 184, rank: 1, isLeader: true, isHighlighted: true)
                    LedgerRow(player: Player(name: "Omar", colorIndex: 1), score: 172, rank: 2)
                    LedgerRow(player: Player(name: "Jules", colorIndex: 3), score: 160, rank: 3)
                }

                OnboardingStatsLine()
            }
        }
    }
}

private struct OnboardingGameCover: View {
    let gameType: GameType
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 5) {
            GameTypeArtwork(gameType: gameType)
                .frame(height: 42)

            Text(gameType.displayName)
                .font(AppFonts.label)
                .foregroundStyle(isSelected ? ClubhouseTheme.felt : ClubhouseTheme.ink)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 82)
        .background(ClubhouseTheme.paperCard, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                .strokeBorder(isSelected ? ClubhouseTheme.felt : ClubhouseTheme.rule, lineWidth: isSelected ? 2 : 1)
        }
    }
}

private struct OnboardingRosterLine: View {
    let name: String
    let colorIndex: Int

    var body: some View {
        HStack(spacing: AppTheme.spacingSmall) {
            PlayerColorPip(colorIndex: colorIndex)
            Text(name)
                .font(AppFonts.body.weight(.semibold))
                .foregroundStyle(ClubhouseTheme.ink)
                .lineLimit(1)
            Spacer()
            Text("roster")
                .columnHeaderStyle()
        }
        .padding(.vertical, 7)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(ClubhouseTheme.rule)
                .frame(height: 1)
        }
    }
}

private struct OnboardingPegStrip: View {
    let currentPhase: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...10, id: \.self) { phase in
                Circle()
                    .fill(
                        phase < currentPhase
                            ? ClubhouseTheme.felt
                            : phase == currentPhase
                                ? ClubhouseTheme.brass
                                : ClubhouseTheme.paperSunken
                    )
                    .frame(width: 13, height: 13)
                    .overlay {
                        Circle()
                            .stroke(ClubhouseTheme.rule, lineWidth: 1)
                    }
            }
        }
        .padding(.top, 3)
    }
}

private struct OnboardingWritingMock: View {
    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                    .fill(Color.white)

                // A little hand-drawn 7: the handwriting entry, in miniature.
                Path { path in
                    path.move(to: CGPoint(x: 14, y: 12))
                    path.addLine(to: CGPoint(x: 40, y: 12))
                    path.addLine(to: CGPoint(x: 24, y: 40))
                }
                .stroke(ClubhouseTheme.ink, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .padding(4)

                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                    .strokeBorder(ClubhouseTheme.ink.opacity(0.72), lineWidth: 1)
            }
            .frame(width: 60, height: 48)

            ZStack {
                Circle()
                    .fill(ClubhouseTheme.blue)
                    .frame(width: 34, height: 34)

                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(ClubhouseTheme.onPrimary)
            }
        }
    }
}

private struct OnboardingStatsLine: View {
    var body: some View {
        HStack(spacing: AppTheme.spacingSmall) {
            PlayerColorPip(colorIndex: 0, size: 12)
            Text("mina leads head-to-head")
                .font(AppFonts.label)
                .foregroundStyle(ClubhouseTheme.ink)
                .lineLimit(1)
            Spacer()
            Text("3-1")
                .font(AppFonts.scoreSmall)
                .monospacedDigit()
                .foregroundStyle(ClubhouseTheme.brass)
        }
        .padding(AppTheme.spacingSmall)
        .background(ClubhouseTheme.paperSunken, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                .strokeBorder(ClubhouseTheme.rule, lineWidth: 1)
        }
    }
}

private struct OnboardingPageDots: View {
    let count: Int
    let selectedPage: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == selectedPage ? ClubhouseTheme.felt : ClubhouseTheme.ink.opacity(0.28))
                    .frame(width: index == selectedPage ? 24 : 8, height: 8)
                    .opacity(index == selectedPage ? 1 : 0.55)
                    .animation(reduceMotion ? AppMotion.fade : AppMotion.state, value: selectedPage)
            }
        }
        .accessibilityLabel("Onboarding page \(selectedPage + 1) of \(count)")
    }
}

private enum OnboardingPage: CaseIterable, Identifiable {
    case scoreFast
    case setupFast
    case toolsAndHistory

    var id: Self { self }

    var title: String {
        switch self {
        case .scoreFast:
            return "put the score pad down"
        case .setupFast:
            return "set up in seconds"
        case .toolsAndHistory:
            return "every night becomes history"
        }
    }

    var accessibilityHint: String {
        switch self {
        case .scoreFast: "pipcount replaces the notes app, napkin, and 'who's winning?'"
        case .setupFast: "pick a game, add your crew once, reuse them every night"
        case .toolsAndHistory: "final scores, stats, and rematches — saved automatically"
        }
    }

    var tint: Color {
        switch self {
        case .scoreFast:
            return ClubhouseTheme.blue
        case .setupFast:
            return ClubhouseTheme.red
        case .toolsAndHistory:
            return ClubhouseTheme.green
        }
    }
}
