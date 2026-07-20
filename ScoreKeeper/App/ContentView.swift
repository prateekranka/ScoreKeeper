import SwiftUI
import SwiftData
import StoreKit

@MainActor @Observable
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
    case headToHead
    case playerStats(String)
    case legalSupport
}

struct ContentView: View {
    @Environment(ReviewAskManager.self) private var reviewAskManager
    @Environment(\.requestReview) private var requestReview
    @State private var router = NavigationRouter()
    @State private var didApplyOnboardingReset = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        NavigationStack(path: $router.path) {
            HomeView()
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    NavigationLink(value: AppDestination.legalSupport) {
                        Text("Legal & Support")
                            .font(AppFonts.caption)
                            .foregroundStyle(ClubhouseTheme.inkMuted)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .accessibilityLabel("PipCount legal and support")
                    .accessibilityHint("Open PipCount privacy policy and support links")
                    .accessibilityIdentifier("legal_support_button")
                }
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
                    case .headToHead:
                        HeadToHeadView()
                    case .playerStats(let playerName):
                        PlayerStatsView(playerName: playerName)
                    case .legalSupport:
                        LegalSupportView()
                    }
                }
        }
        .environment(router)
        .fullScreenCover(isPresented: onboardingBinding) {
            OnboardingView {
                hasCompletedOnboarding = true
            }
        }
        .onChange(of: reviewAskManager.reviewRequestPending) { _, isPending in
            guard isPending else { return }
            reviewAskManager.consumeReviewRequest()
            requestReview()
        }
        .onAppear(perform: resetOnboardingIfRequested)
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

private struct OnboardingView: View {
    let finish: () -> Void
    @State private var selectedPage = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let pages = OnboardingPage.allCases

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PipCount")
                        .font(AppFonts.largeTitle)
                        .foregroundStyle(ClubhouseTheme.ink)
                    Text("Game night, organized.")
                        .font(AppFonts.caption)
                        .foregroundStyle(ClubhouseTheme.inkMuted)
                }

                Spacer()

                Button("Skip", action: finish)
                    .font(AppFonts.body)
                    .foregroundStyle(ClubhouseTheme.inkMuted)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityIdentifier("onboarding_skip_button")
            }
            .padding(.horizontal, AppTheme.spacingMedium)
            .padding(.top, AppTheme.spacingSmall)

            TabView(selection: $selectedPage) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                    OnboardingPageView(page: page, highlightsVisible: selectedPage == index)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack(spacing: AppTheme.spacingMedium) {
                OnboardingPageDots(count: pages.count, selectedPage: selectedPage)

                BauhausPrimaryButton(
                    title: selectedPage == pages.count - 1 ? "Start keeping score" : "Continue",
                    systemImage: selectedPage == pages.count - 1 ? "play.fill" : "arrow.right",
                    fill: ClubhouseTheme.bauhausBlue,
                    action: primaryAction
                )
                .accessibilityIdentifier("onboarding_primary_button")
            }
            .padding(AppTheme.spacingMedium)
            .appGlass(cornerRadius: AppTheme.cornerRadiusLarge, isInteractive: true)
            .padding(.horizontal, AppTheme.spacingMedium)
            .padding(.bottom, AppTheme.spacingSmall)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                OnboardingArtwork(page: page, isVisible: highlightsVisible)
                    .padding(.top, 10)

                VStack(spacing: AppTheme.spacingSmall) {
                    Text(page.title)
                        .font(AppFonts.largeTitle)
                        .foregroundStyle(ClubhouseTheme.ink)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("onboarding_page_title")
                        .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 0.82 : 1)

                    Text(page.message)
                        .font(AppFonts.body)
                        .foregroundStyle(ClubhouseTheme.inkMuted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: AppTheme.spacingSmall) {
                    ForEach(Array(page.highlights.enumerated()), id: \.element) { index, highlight in
                        OnboardingHighlightRow(highlight: highlight, tint: page.tint)
                            .opacity(highlightsVisible ? 1 : 0)
                            .offset(y: highlightsVisible || reduceMotion ? 0 : 6)
                            .animation(
                                reduceMotion ? AppMotion.fade :
                                    AppMotion.page.delay(Double(index) * 0.04),
                                value: highlightsVisible
                            )
                    }
                }
            }
            .padding(.horizontal, AppTheme.spacingMedium)
            .padding(.bottom, 132)
        }
        .accessibilityElement(children: .contain)
    }
}

private struct OnboardingArtwork: View {
    let page: OnboardingPage
    let isVisible: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            BauhausCornerTexture()
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))

            artworkContent
                .padding(AppTheme.spacingLarge)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 220)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge)
        .scaleEffect(isVisible || reduceMotion ? 1 : 0.97)
        .opacity(isVisible ? 1 : 0)
        .animation(reduceMotion ? AppMotion.fade : AppMotion.criticallyDamped, value: isVisible)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var artworkContent: some View {
        switch page {
        case .scoreFast:
            VStack(spacing: AppTheme.spacingMedium) {
                BauhausHeroArt(style: .scoring, height: 110)

                HStack(spacing: AppTheme.spacingSmall) {
                    ForEach(0..<3, id: \.self) { index in
                        HStack(spacing: 6) {
                            PlayerShapeIcon(colorIndex: index, size: 22)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(PlayerColors.color(for: index))
                                .frame(width: 36, height: 8)
                        }
                    }
                }

                BauhausRoundDots(current: 4, total: 10)
            }
        case .setupFast:
            VStack(spacing: AppTheme.spacingMedium) {
                BauhausHeroArt(style: .addPlayers, height: 110)

                HStack(spacing: AppTheme.spacingSmall) {
                    ForEach(0..<3, id: \.self) { index in
                        PlayerShapeIcon(colorIndex: index, size: 28)
                    }
                }

                HStack(spacing: AppTheme.spacingSmall) {
                    Circle()
                        .fill(ClubhouseTheme.bauhausBlue)
                        .frame(width: 28, height: 28)
                        .overlay {
                            Image(systemName: "plus")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                        }
                    Circle()
                        .fill(ClubhouseTheme.bauhausYellow)
                        .frame(width: 28, height: 28)
                        .overlay {
                            Image(systemName: "person.2.fill")
                                .font(.caption2.bold())
                                .foregroundStyle(ClubhouseTheme.ink)
                        }
                }
            }
        case .toolsAndHistory:
            VStack(spacing: AppTheme.spacingMedium) {
                BauhausHeroArt(style: .gameOver, height: 110)

                HStack(spacing: AppTheme.spacingSmall) {
                    StatusPill(kind: .completed)
                    BauhausStar(color: ClubhouseTheme.bauhausYellow)
                        .frame(width: 18, height: 18)
                }

                HStack(spacing: AppTheme.spacingSmall) {
                    ForEach(0..<3, id: \.self) { index in
                        VStack(spacing: 4) {
                            PlayerShapeIcon(colorIndex: index, size: 20)
                            Text(["128", "116", "94"][index])
                                .font(AppFonts.scoreSmall)
                                .monospacedDigit()
                                .foregroundStyle(PlayerColors.color(for: index))
                        }
                    }
                }
            }
        }
    }
}

private struct OnboardingHighlightRow: View {
    let highlight: String
    let tint: Color

    var body: some View {
        HStack(spacing: AppTheme.spacingSmall) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(ClubhouseTheme.bauhausBlue)
                .accessibilityHidden(true)
            Text(highlight)
                .font(AppFonts.body)
                .foregroundStyle(ClubhouseTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: AppTheme.spacingSmall)
        }
        .padding(AppTheme.spacingSmall)
        .background(ClubhouseTheme.paperCard, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
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
                Circle()
                    .fill(index == selectedPage ? ClubhouseTheme.bauhausBlue : ClubhouseTheme.ink.opacity(0.22))
                    .frame(width: 8, height: 8)
                    .scaleEffect(index == selectedPage && !reduceMotion ? 1.25 : 1)
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
            return "Put the score pad down."
        case .setupFast:
            return "Set up in seconds."
        case .toolsAndHistory:
            return "Every night becomes history."
        }
    }

    var message: String {
        switch self {
        case .scoreFast:
            return "PipCount replaces the notes app, napkin, and 'who's winning?'"
        case .setupFast:
            return "Pick a game, add your crew once, reuse them every night."
        case .toolsAndHistory:
            return "Final scores, stats, and rematches - saved automatically."
        }
    }

    var highlights: [String] {
        switch self {
        case .scoreFast:
            return ["Live ledger totals", "Large score controls", "Undo for scoring mistakes"]
        case .setupFast:
            return ["Scoreboard, Ten Phases, and What's for Dinner", "Reusable player roster", "Game-specific setup"]
        case .toolsAndHistory:
            return ["Final standings archive", "Player stats and head-to-heads", "Rematches with the same crew"]
        }
    }

    var tint: Color {
        switch self {
        case .scoreFast:
            return PlayerColors.palette[0]
        case .setupFast:
            return PlayerColors.palette[1]
        case .toolsAndHistory:
            return PlayerColors.palette[3]
        }
    }
}
