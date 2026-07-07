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
    @State private var router = NavigationRouter()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

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
        !hasCompletedOnboarding && !ProcessInfo.processInfo.arguments.contains("-in-memory-store")
    }
}

private struct OnboardingView: View {
    let finish: () -> Void
    @State private var selectedPage = 0
    @State private var highlightsVisible = false

    private let pages = OnboardingPage.allCases

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedPage) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                    OnboardingPageView(page: page, highlightsVisible: selectedPage == index)
                        .tag(index)
                        .padding(.horizontal, AppTheme.spacingLarge)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            VStack(spacing: AppTheme.spacingSmall) {
                AppActionButton(role: .primary(pages[selectedPage].tint), action: primaryAction) {
                    Label(selectedPage == pages.count - 1 ? "Start Keeping Score" : "Continue",
                          systemImage: selectedPage == pages.count - 1 ? "play.fill" : "arrow.right")
                }

                Button("Skip", action: finish)
                    .font(AppFonts.body)
                    .foregroundStyle(.secondary)
                    .frame(minHeight: 44)
            }
            .padding(AppTheme.spacingMedium)
            .background(.ultraThinMaterial)
        }
        .appBackground()
    }

    private func primaryAction() {
        guard selectedPage < pages.count - 1 else {
            finish()
            return
        }

        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
            selectedPage += 1
        }
    }
}

private struct OnboardingPageView: View {
    let page: OnboardingPage
    let highlightsVisible: Bool

    var body: some View {
        VStack(spacing: AppTheme.spacingLarge) {
            Spacer(minLength: AppTheme.spacingXLarge)

            ZStack {
                Circle()
                    .fill(page.tint.opacity(0.16))
                    .frame(width: 132, height: 132)

                Image(systemName: page.systemImage)
                    .font(.system(size: 52, weight: .semibold, design: .rounded))
                    .foregroundStyle(page.tint)
                    .accessibilityHidden(true)
            }
            .scaleEffect(highlightsVisible ? 1 : 0.85)
            .animation(.spring(response: 0.5, dampingFraction: 0.65), value: highlightsVisible)

            VStack(spacing: AppTheme.spacingSmall) {
                Text(page.title)
                    .font(AppFonts.largeTitle)
                    .multilineTextAlignment(.center)

                Text(page.message)
                    .font(AppFonts.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: AppTheme.spacingSmall) {
                ForEach(Array(page.highlights.enumerated()), id: \.element) { index, highlight in
                    HStack(spacing: AppTheme.spacingSmall) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(page.tint)
                        Text(highlight)
                            .font(AppFonts.body)
                        Spacer()
                    }
                    .padding(AppTheme.spacingSmall)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
                    .opacity(highlightsVisible ? 1 : 0)
                    .offset(y: highlightsVisible ? 0 : 8)
                    .animation(
                        .spring(response: 0.4, dampingFraction: 0.7)
                            .delay(Double(index) * 0.08),
                        value: highlightsVisible
                    )
                }
            }

            Spacer(minLength: AppTheme.spacingXLarge)
        }
        .accessibilityElement(children: .contain)
    }
}

private enum OnboardingPage: CaseIterable, Identifiable {
    case scoreFast
    case gameTools
    case rememberNights

    var id: Self { self }

    var title: String {
        switch self {
        case .scoreFast:
            return "Score the round fast"
        case .gameTools:
            return "Keep the table moving"
        case .rememberNights:
            return "Turn games into history"
        }
    }

    var message: String {
        switch self {
        case .scoreFast:
            return "Pick a game, add your crew, and enter points with big one-tap controls."
        case .gameTools:
            return "Timer, dice, random starter, and undo are always close during play."
        case .rememberNights:
            return "See score trends, rematch quickly, and compare rivalries across game nights."
        }
    }

    var highlights: [String] {
        switch self {
        case .scoreFast:
            return ["Scoreboard, Phase 10, and Dinner modes", "Saved player roster", "Smart defaults per game"]
        case .gameTools:
            return ["Undo the last round", "Random starter picker", "Built-in timer and dice"]
        case .rememberNights:
            return ["Final standings", "Score trends", "Head-to-head stats"]
        }
    }

    var systemImage: String {
        switch self {
        case .scoreFast:
            return "plus.forwardslash.minus"
        case .gameTools:
            return "timer"
        case .rememberNights:
            return "chart.line.uptrend.xyaxis"
        }
    }

    var tint: Color {
        switch self {
        case .scoreFast:
            return PlayerColors.palette[0]
        case .gameTools:
            return PlayerColors.palette[1]
        case .rememberNights:
            return PlayerColors.palette[3]
        }
    }
}
