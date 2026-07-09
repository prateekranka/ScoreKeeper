import SwiftUI
import SwiftData

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
}

struct ContentView: View {
    @Environment(ReviewAskManager.self) private var reviewAskManager
    @State private var router = NavigationRouter()
    @State private var didApplyOnboardingReset = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        @Bindable var reviewAskManager = reviewAskManager

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
                    case .headToHead:
                        HeadToHeadView()
                    case .playerStats(let playerName):
                        PlayerStatsView(playerName: playerName)
                    }
                }
        }
        .environment(router)
        .fullScreenCover(isPresented: onboardingBinding) {
            OnboardingView {
                hasCompletedOnboarding = true
            }
        }
        .sheet(isPresented: $reviewAskManager.isPresentingReviewAsk) {
            ReviewAskView()
                .presentationDetents([.medium])
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
                    Text("ScoreKeeper")
                        .font(AppFonts.headline)
                    Text("Game night, under control")
                        .font(AppFonts.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Skip", action: finish)
                    .font(AppFonts.body)
                    .foregroundStyle(.secondary)
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

                AppActionButton(role: .primary(ClubhouseTheme.felt), action: primaryAction) {
                    Label(selectedPage == pages.count - 1 ? "Start keeping score" : "Continue",
                          systemImage: selectedPage == pages.count - 1 ? "play.fill" : "arrow.right")
                }
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

        withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.78)) {
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
                            .opacity(highlightsVisible || reduceMotion ? 1 : 0)
                            .offset(y: highlightsVisible || reduceMotion ? 0 : 8)
                            .animation(
                                reduceMotion ? nil :
                                    .spring(response: 0.4, dampingFraction: 0.7)
                                    .delay(Double(index) * 0.06),
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
    @State private var scoreInput = 12

    var body: some View {
        artworkContent
            .padding(AppTheme.spacingMedium)
        .frame(maxWidth: .infinity)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge)
        .scaleEffect(isVisible || reduceMotion ? 1 : 0.96)
        .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.72), value: isVisible)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var artworkContent: some View {
        switch page {
        case .scoreFast:
            VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                HStack {
                    Text("Round 4")
                        .columnHeaderStyle()
                    Spacer()
                    Text("Live")
                        .columnHeaderStyle()
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
                    PipStepper(value: $scoreInput, range: -99...99)
                        .scaleEffect(0.82)
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
                    Text("Tonight's Crew")
                        .columnHeaderStyle()
                    Spacer()
                    Text("Saved")
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
                        Text("Final Scores")
                            .columnHeaderStyle()
                        Text("Game night archive")
                            .font(AppFonts.caption)
                            .foregroundStyle(ClubhouseTheme.inkMuted)
                    }

                    Spacer()

                    StampBadge(text: "Final")
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
                .frame(height: 36)
            Text(gameType.displayName)
                .font(AppFonts.caption)
                .foregroundStyle(isSelected ? ClubhouseTheme.felt : ClubhouseTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 76)
        .background(ClubhouseTheme.paperCard, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                .strokeBorder(isSelected ? ClubhouseTheme.felt : ClubhouseTheme.rule, lineWidth: 1)
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
                .font(AppFonts.body)
                .foregroundStyle(ClubhouseTheme.ink)
                .lineLimit(1)
            Spacer()
            Text("Roster")
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
                    .fill(phase < currentPhase ? ClubhouseTheme.felt : phase == currentPhase ? ClubhouseTheme.brass : ClubhouseTheme.paperSunken)
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

private struct OnboardingStatsLine: View {
    var body: some View {
        HStack(spacing: AppTheme.spacingSmall) {
            PlayerColorPip(colorIndex: 0, size: 12)
            Text("Mina leads head-to-head")
                .font(AppFonts.caption)
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

private struct OnboardingHighlightRow: View {
    let highlight: String
    let tint: Color

    var body: some View {
        HStack(spacing: AppTheme.spacingSmall) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(ClubhouseTheme.felt)
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

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(index == selectedPage ? ClubhouseTheme.felt : ClubhouseTheme.ink.opacity(0.28))
                    .frame(width: index == selectedPage ? 10 : 7, height: index == selectedPage ? 10 : 7)
                    .animation(.spring(response: 0.3, dampingFraction: 0.75), value: selectedPage)
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
            return "ScoreKeeper replaces the notes app, napkin, and 'who's winning?'"
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
            return ["Scoreboard, Phase 10, and What's for Dinner", "Reusable player roster", "Game-specific setup"]
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
