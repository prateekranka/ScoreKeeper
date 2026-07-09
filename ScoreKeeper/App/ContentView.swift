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
    @State private var didApplyOnboardingReset = false
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

                AppActionButton(role: .primary(pages[selectedPage].tint), action: primaryAction) {
                    Label(selectedPage == pages.count - 1 ? "Start Keeping Score" : "Continue",
                          systemImage: selectedPage == pages.count - 1 ? "play.fill" : "arrow.right")
                }
                .accessibilityIdentifier("onboarding_primary_button")
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
            VStack(spacing: AppTheme.spacingMedium) {
                OnboardingArtwork(page: page, isVisible: highlightsVisible)
                    .padding(.top, AppTheme.spacingMedium)

                VStack(spacing: AppTheme.spacingSmall) {
                    Text(page.title)
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("onboarding_page_title")
                        .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 0.82 : 1)

                    Text(page.message)
                        .font(AppFonts.body)
                        .foregroundStyle(.secondary)
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
            .padding(.bottom, AppTheme.spacingMedium)
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
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                .fill(.regularMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                        .stroke(page.tint.opacity(0.35), lineWidth: 1)
                }

            Circle()
                .fill(page.tint.opacity(0.14))
                .frame(width: 172, height: 172)
                .offset(x: 82, y: -48)
                .accessibilityHidden(true)

            artworkContent
                .padding(AppTheme.spacingMedium)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 248)
        .scaleEffect(isVisible || reduceMotion ? 1 : 0.96)
        .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.72), value: isVisible)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var artworkContent: some View {
        switch page {
        case .scoreFast:
            VStack(spacing: AppTheme.spacingSmall) {
                HStack {
                    Label("Round 4", systemImage: "plus.forwardslash.minus")
                        .font(AppFonts.headline)
                        .foregroundStyle(page.tint)
                    Spacer()
                    Text("Live")
                        .font(AppFonts.caption)
                        .padding(.horizontal, AppTheme.spacingSmall)
                        .padding(.vertical, 5)
                        .background(page.tint.opacity(0.18), in: Capsule())
                }

                OnboardingScoreRow(name: "Mina", score: "128", color: PlayerColors.palette[0], isLeading: true)
                OnboardingScoreRow(name: "Omar", score: "116", color: PlayerColors.palette[1], isLeading: false)
                OnboardingScoreRow(name: "Jules", score: "94", color: PlayerColors.palette[3], isLeading: false)

                HStack(spacing: AppTheme.spacingSmall) {
                    OnboardingStepperButton(systemImage: "minus", tint: PlayerColors.palette[0])
                    Text("12")
                        .font(AppFonts.scoreMedium)
                        .monospacedDigit()
                        .frame(maxWidth: .infinity)
                    OnboardingStepperButton(systemImage: "plus", tint: PlayerColors.palette[1])
                }
            }
        case .setupFast:
            VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
                HStack(spacing: AppTheme.spacingSmall) {
                    OnboardingGameChip(title: "Scoreboard", systemImage: "list.number", tint: PlayerColors.palette[3], isSelected: true)
                    OnboardingGameChip(title: "Phase 10", systemImage: "10.circle.fill", tint: PlayerColors.palette[0], isSelected: false)
                }

                Text("Tonight's crew")
                    .font(AppFonts.headline)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.spacingSmall) {
                    ForEach(Array(["Mina", "Omar", "Jules", "Nora"].enumerated()), id: \.element) { index, name in
                        HStack(spacing: AppTheme.spacingSmall) {
                            Circle()
                                .fill(PlayerColors.color(for: index))
                                .frame(width: 14, height: 14)
                            Text(name)
                                .font(AppFonts.body)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .padding(AppTheme.spacingSmall)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
                    }
                }

                Label("Smart defaults are ready before the first round.", systemImage: "wand.and.stars")
                    .font(AppFonts.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .toolsAndHistory:
            VStack(spacing: AppTheme.spacingMedium) {
                HStack(spacing: AppTheme.spacingSmall) {
                    OnboardingToolBadge(title: "Timer", systemImage: "timer", tint: PlayerColors.palette[1])
                    OnboardingToolBadge(title: "Dice", systemImage: "die.face.5.fill", tint: PlayerColors.palette[4])
                    OnboardingToolBadge(title: "Starter", systemImage: "shuffle", tint: PlayerColors.palette[3])
                }

                VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                    OnboardingHistoryLine(title: "Final standings", value: "Mina won by 12", systemImage: "trophy.fill", tint: PlayerColors.palette[2])
                    OnboardingHistoryLine(title: "Rematch", value: "Same crew, one tap", systemImage: "arrow.counterclockwise", tint: PlayerColors.palette[0])
                    OnboardingHistoryLine(title: "Stats", value: "Head-to-head trends", systemImage: "chart.line.uptrend.xyaxis", tint: PlayerColors.palette[3])
                }
            }
        }
    }
}

private struct OnboardingScoreRow: View {
    let name: String
    let score: String
    let color: Color
    let isLeading: Bool

    var body: some View {
        HStack(spacing: AppTheme.spacingSmall) {
            Circle()
                .fill(color)
                .frame(width: 14, height: 14)
            Text(name)
                .font(AppFonts.body)
            Spacer()
            if isLeading {
                Image(systemName: "crown.fill")
                    .foregroundStyle(PlayerColors.palette[2])
            }
            Text(score)
                .font(AppFonts.scoreSmall)
                .monospacedDigit()
        }
        .padding(AppTheme.spacingSmall)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
    }
}

private struct OnboardingStepperButton: View {
    let systemImage: String
    let tint: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(AppFonts.headline)
            .foregroundStyle(.white)
            .frame(width: 48, height: 44)
            .background(tint.gradient, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
    }
}

private struct OnboardingGameChip: View {
    let title: String
    let systemImage: String
    let tint: Color
    let isSelected: Bool

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(AppFonts.caption)
            .lineLimit(1)
            .padding(.horizontal, AppTheme.spacingSmall)
            .frame(maxWidth: .infinity, minHeight: 48)
            .foregroundStyle(isSelected ? .white : .primary)
            .background(isSelected ? AnyShapeStyle(tint.gradient) : AnyShapeStyle(.regularMaterial),
                        in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
    }
}

private struct OnboardingToolBadge: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(AppFonts.headline)
                .foregroundStyle(tint)
            Text(title)
                .font(AppFonts.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 72)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
    }
}

private struct OnboardingHistoryLine: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: AppTheme.spacingSmall) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFonts.body)
                Text(value)
                    .font(AppFonts.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(AppTheme.spacingSmall)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
    }
}

private struct OnboardingHighlightRow: View {
    let highlight: String
    let tint: Color

    var body: some View {
        HStack(spacing: AppTheme.spacingSmall) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(highlight)
                .font(AppFonts.body)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: AppTheme.spacingSmall)
        }
        .padding(AppTheme.spacingSmall)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
    }
}

private struct OnboardingPageDots: View {
    let count: Int
    let selectedPage: Int

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == selectedPage ? PlayerColors.palette[3] : Color.secondary.opacity(0.28))
                    .frame(width: index == selectedPage ? 20 : 7, height: 7)
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
            return "Score every round fast"
        case .setupFast:
            return "Set up the table in seconds"
        case .toolsAndHistory:
            return "Keep the night going"
        }
    }

    var message: String {
        switch self {
        case .scoreFast:
            return "Big tap targets, clear totals, and round-by-round scoring make ScoreKeeper faster than passing paper around."
        case .setupFast:
            return "Choose Scoreboard, Phase 10, or What's for Dinner, add your crew, and start with sensible defaults."
        case .toolsAndHistory:
            return "Timer, dice, starter picker, undo, final standings, stats, and rematches stay close without slowing play."
        }
    }

    var highlights: [String] {
        switch self {
        case .scoreFast:
            return ["Enter points with large controls", "See leaders and totals at a glance", "Undo mistakes during live play"]
        case .setupFast:
            return ["Reusable player roster", "Game-specific defaults", "Fast path from setup to round one"]
        case .toolsAndHistory:
            return ["Built-in game night tools", "History, stats, and rivalries", "One-tap rematches after the final score"]
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
