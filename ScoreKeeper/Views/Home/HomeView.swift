import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(NavigationRouter.self) private var router
    @Environment(ThemeManager.self) private var themeManager
    @State private var selectedTool: HomeTool?
    @State private var sectionsVisible = false
    @Query(filter: #Predicate<GameSession> { !$0.isComplete },
           sort: \GameSession.createdAt, order: .reverse)
    private var inProgressGames: [GameSession]
    @Query(filter: #Predicate<GameSession> { $0.isComplete },
           sort: \GameSession.createdAt, order: .reverse)
    private var completedGames: [GameSession]

    private var headerSubtitle: String {
        if let activeGame = inProgressGames.first {
            return "Round \(activeGame.currentRoundNumber) is waiting."
        }
        return completedGames.isEmpty ? "Ready to play?" : "\(completedGames.count) completed games"
    }

    private var uniquePlayerCount: Int {
        let names = completedGames
            .flatMap(\.players)
            .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        return Set(names).count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacingLarge) {
                HomeHeader(
                    subtitle: headerSubtitle,
                    themeIconName: themeManager.iconName,
                    onThemeTap: cycleTheme
                )
                .staggeredEntrance(visible: sectionsVisible, index: 0)

                NewGameButton(action: { router.push(.gamePicker) })
                    .staggeredEntrance(visible: sectionsVisible, index: 1)
                    .padding(.top, AppTheme.spacingMedium)

                HomeDashboardRow(
                    gamesCount: completedGames.count,
                    activeCount: inProgressGames.count,
                    playersCount: uniquePlayerCount
                )
                .staggeredEntrance(visible: sectionsVisible, index: 2)

                HomeQuickToolsRow(selectedTool: $selectedTool)
                    .staggeredEntrance(visible: sectionsVisible, index: 3)

                if let activeGame = inProgressGames.first {
                    HomeResumeBanner(session: activeGame, onTap: { router.push(.scoring(activeGame.persistentModelID)) })
                        .staggeredEntrance(visible: sectionsVisible, index: 4)
                } else if completedGames.isEmpty {
                    EmptyStateView(
                        title: "No games yet",
                        systemImage: "sparkles",
                        message: "Start with a scoreboard, Phase 10, or What's for Dinner."
                    )
                    .staggeredEntrance(visible: sectionsVisible, index: 4)
                }

                if !completedGames.isEmpty {
                    HomeRecentGamesSection(
                        sessions: completedGames,
                        onGameTap: { router.push(.gameDetail($0)) },
                        onSeeAll: { router.push(.gameHistory) }
                    )
                    .staggeredEntrance(visible: sectionsVisible, index: 5)

                    HomeStatsSection(sessions: completedGames)
                        .staggeredEntrance(visible: sectionsVisible, index: 6)
                }
            }
            .padding(AppTheme.spacingMedium)
        }
        .appBackground()
        .navigationTitle("")
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $selectedTool) { tool in
            HomeToolSheet(tool: tool, activeGame: inProgressGames.first)
                .presentationDetents([.medium])
        }
        .onAppear(perform: revealSections)
    }

    private func cycleTheme() {
        themeManager.cycle()
    }

    private func revealSections() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
            sectionsVisible = true
        }
    }

    private func resultText(for session: GameSession) -> String? {
        let engine = GameEngineFactory.engine(for: session.gameType)
        let winnerIDs = engine.winners(session: session)
        guard !winnerIDs.isEmpty else { return "No winner" }

        let names = session.players
            .filter { winnerIDs.contains($0.id) }
            .map(\.name)

        return names.count == 1 ? "\(names[0]) won" : "\(names.joined(separator: " & ")) won"
    }
}

// MARK: - Subviews

private struct HomeHeader: View {
    let subtitle: String
    let themeIconName: String
    let onThemeTap: () -> Void
    @State private var themeTrigger = 0

    var body: some View {
        VStack(spacing: AppTheme.spacingSmall) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ScoreKeeper")
                        .font(AppFonts.largeTitle)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [PlayerColors.palette[0], PlayerColors.palette[3], PlayerColors.palette[1]],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    Text(subtitle)
                        .font(AppFonts.body)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    themeTrigger &+= 1
                    onThemeTap()
                } label: {
                    Image(systemName: themeIconName)
                        .font(.title3)
                        .frame(width: 44, height: 44)
                        .appGlass(cornerRadius: AppTheme.cornerRadiusMedium, isInteractive: true)
                }
                .accessibilityLabel("Change appearance")
                .accessibilityIdentifier("theme_button")
                .buttonStyle(PressableButtonStyle())
                .sensoryFeedback(.selection, trigger: themeTrigger)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.top, 40)
    }
}

private struct NewGameButton: View {
    let action: () -> Void

    var body: some View {
        AppActionButton(role: .primary(PlayerColors.palette[3]), action: action) {
            Label("New Game", systemImage: "plus.circle.fill")
        }
        .accessibilityIdentifier("new_game_button")
    }
}

private struct HomeDashboardRow: View {
    let gamesCount: Int
    let activeCount: Int
    let playersCount: Int

    var body: some View {
        glassGroup(spacing: AppTheme.spacingSmall) {
            HStack(spacing: AppTheme.spacingSmall) {
                HomeMetricCard(title: "Games", value: "\(gamesCount)", systemImage: "trophy.fill", tint: PlayerColors.palette[2])
                HomeMetricCard(title: "Active", value: "\(activeCount)", systemImage: "play.circle.fill", tint: .green)
                HomeMetricCard(title: "Players", value: "\(playersCount)", systemImage: "person.2.fill", tint: PlayerColors.palette[1])
            }
        }
    }
}

private struct HomeMetricCard: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .accessibilityHidden(true)

            Text(value)
                .font(AppFonts.scoreSmall)
                .monospacedDigit()

            Text(title)
                .font(AppFonts.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.spacingSmall)
        .appGlass(cornerRadius: AppTheme.cornerRadiusSmall)
        .accessibilityElement(children: .combine)
    }
}

private struct HomeQuickToolsRow: View {
    @Binding var selectedTool: HomeTool?

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            AppSectionHeader(
                title: "Game Night Tools",
                subtitle: "Timer, dice, starter, and undo help are one tap away.",
                systemImage: "sparkles"
            )

            glassGroup(spacing: AppTheme.spacingSmall) {
                HStack(spacing: AppTheme.spacingSmall) {
                    ForEach(HomeTool.allCases) { tool in
                        HomeToolButton(tool: tool) {
                            selectedTool = tool
                        }
                    }
                }
            }
        }
    }
}

private struct HomeToolButton: View {
    let tool: HomeTool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: tool.systemImage)
                    .font(.title3)
                    .frame(width: 36, height: 36)
                    .background(tool.tint.opacity(0.16), in: Circle())
                    .foregroundStyle(tool.tint)

                Text(tool.title)
                    .font(AppFonts.caption)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 86)
            .padding(.horizontal, 4)
            .appGlass(cornerRadius: AppTheme.cornerRadiusSmall, isInteractive: true)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(tool.accessibilityLabel)
    }
}

private struct HomeResumeBanner: View {
    let session: GameSession
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                HStack {
                    Image(systemName: "play.circle.fill")
                        .foregroundStyle(.green)
                    Text("Resume Game")
                        .font(AppFonts.headline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: AppTheme.spacingSmall) {
                    Image(systemName: session.gameType.icon)
                        .foregroundStyle(session.gameType.color)
                    Text(session.gameType.displayName)
                        .font(AppFonts.body)
                    Text("·").foregroundStyle(.secondary)
                    Text("\(session.players.count) players")
                        .font(AppFonts.body)
                        .foregroundStyle(.secondary)
                    Text("·").foregroundStyle(.secondary)
                    Text("Round \(session.sortedRounds.count)")
                        .font(AppFonts.body)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: AppTheme.spacingSmall) {
                    ForEach(session.players, id: \.id) { player in
                        PlayerBadge(name: player.name, colorIndex: player.colorIndex, size: .small, showName: false)
                    }
                }
            }
            .padding(AppTheme.spacingMedium)
            .appGlass(cornerRadius: AppTheme.cornerRadiusMedium, isInteractive: true)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityIdentifier("resume_game_card")
        .accessibilityLabel("Resume \(session.gameType.displayName), round \(session.currentRoundNumber)")
    }
}

private struct HomeRecentGamesSection: View {
    let sessions: [GameSession]
    let onGameTap: (PersistentIdentifier) -> Void
    let onSeeAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            HStack {
                AppSectionHeader(title: "Recent Games", systemImage: "clock")
                Spacer()
                if !sessions.isEmpty {
                    Button("See All", action: onSeeAll)
                        .font(AppFonts.body)
                        .accessibilityIdentifier("see_all_button")
                }
            }

            ForEach(sessions.prefix(5)) { session in
                Button {
                    onGameTap(session.persistentModelID)
                } label: {
                    RecentGameRow(session: session)
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
    }
}

private struct RecentGameRow: View {
    let session: GameSession

    private var resultText: String? {
        let engine = GameEngineFactory.engine(for: session.gameType)
        let winnerIDs = engine.winners(session: session)
        guard !winnerIDs.isEmpty else { return "No winner" }

        let names = session.players
            .filter { winnerIDs.contains($0.id) }
            .map(\.name)

        return names.count == 1 ? "\(names[0]) won" : "\(names.joined(separator: " & ")) won"
    }

    var body: some View {
        HStack(spacing: AppTheme.spacingSmall) {
            Image(systemName: session.gameType.icon)
                .font(.title3)
                .foregroundStyle(session.gameType.color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.gameType.displayName)
                    .font(AppFonts.body)

                if let resultText {
                    Text(resultText)
                        .font(AppFonts.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(session.players.count) players")
                        .font(AppFonts.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let date = session.completedAt {
                Text(date, style: .date)
                    .font(AppFonts.caption)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(AppTheme.spacingSmall)
        .appGlass(cornerRadius: AppTheme.cornerRadiusSmall, isInteractive: true)
    }
}

private struct HomeStatsSection: View {
    @Environment(NavigationRouter.self) private var router
    let sessions: [GameSession]

    private var playerNames: [String] {
        StatsCalculator.allPlayerNames(from: sessions)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            AppSectionHeader(title: "Stats", subtitle: "Compare players across completed games", systemImage: "chart.bar")

            Button {
                router.push(.headToHead)
            } label: {
                Label("Head to Head", systemImage: "person.2.slash")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppTheme.spacingMedium)
                    .appGlass(cornerRadius: AppTheme.cornerRadiusMedium, isInteractive: true)
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityIdentifier("head_to_head_button")

            if !playerNames.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppTheme.spacingSmall) {
                        ForEach(playerNames, id: \.self) { name in
                            Button {
                                router.push(.playerStats(name))
                            } label: {
                                Label(name, systemImage: "person.crop.circle")
                                    .font(AppFonts.body)
                                    .padding(.horizontal, AppTheme.spacingSmall)
                                    .frame(minHeight: 42)
                                    .background(.regularMaterial, in: Capsule())
                            }
                            .buttonStyle(PressableButtonStyle())
                            .accessibilityIdentifier("player_stats_\(name)")
                        }
                    }
                }
                .accessibilityIdentifier("player_stats_entry_list")
            }
        }
    }
}

// MARK: - Home Tools

private enum HomeTool: String, CaseIterable, Identifiable {
    case timer
    case dice
    case starter
    case undo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .timer: return "Timer"
        case .dice: return "Dice"
        case .starter: return "Starter"
        case .undo: return "Undo"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .timer: return "Open game timer"
        case .dice: return "Roll dice"
        case .starter: return "Pick a random starter"
        case .undo: return "Learn about undo"
        }
    }

    var systemImage: String {
        switch self {
        case .timer: return "timer"
        case .dice: return "die.face.5.fill"
        case .starter: return "shuffle"
        case .undo: return "arrow.uturn.backward.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .timer: return PlayerColors.palette[1]
        case .dice: return PlayerColors.palette[4]
        case .starter: return PlayerColors.palette[3]
        case .undo: return PlayerColors.palette[0]
        }
    }
}

// MARK: - Tool Sheet

private struct HomeToolSheet: View {
    let tool: HomeTool
    let activeGame: GameSession?
    @Environment(\.dismiss) private var dismiss
    @State private var dieRoll = 1
    @State private var selectedStarter: Player?

    var body: some View {
        NavigationStack {
            VStack(spacing: AppTheme.spacingLarge) {
                Image(systemName: tool.systemImage)
                    .font(.system(size: 52, weight: .semibold, design: .rounded))
                    .foregroundStyle(tool.tint)
                    .frame(width: 96, height: 96)
                    .background(tool.tint.opacity(0.16), in: Circle())
                    .accessibilityHidden(true)

                VStack(spacing: AppTheme.spacingSmall) {
                    Text(toolTitle)
                        .font(AppFonts.title)
                    Text(toolMessage)
                        .font(AppFonts.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                ToolSheetContent(tool: tool, activeGame: activeGame, dieRoll: $dieRoll, selectedStarter: $selectedStarter)

                Spacer()
            }
            .padding(AppTheme.spacingLarge)
            .navigationTitle(tool.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var toolTitle: String {
        switch tool {
        case .timer: return "Keep turns moving"
        case .dice: return "Roll a quick die"
        case .starter: return "Choose who starts"
        case .undo: return "Fix mistakes safely"
        }
    }

    private var toolMessage: String {
        switch tool {
        case .timer:
            return "A visible timer reduces table drift without leaving the score sheet."
        case .dice:
            return "Use a fast roll when a game needs a tie-breaker or random choice."
        case .starter:
            return activeGame == nil ? "Start or resume a game to pick from its player list." : "Randomly pick from the current players."
        case .undo:
            return "Scorekeeping mistakes happen. The live sheet keeps undo close to the submit button."
        }
    }
}

private struct ToolSheetContent: View {
    let tool: HomeTool
    let activeGame: GameSession?
    @Binding var dieRoll: Int
    @Binding var selectedStarter: Player?

    var body: some View {
        switch tool {
        case .timer:
            Label("Use the live scoring toolbar timer during a game.", systemImage: "timer")
                .font(AppFonts.body)
        case .dice:
            VStack(spacing: AppTheme.spacingSmall) {
                Text("\(dieRoll)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .monospacedDigit()
                AppActionButton(role: .primary(tool.tint)) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        dieRoll = Int.random(in: 1...6)
                    }
                } label: {
                    Label("Roll", systemImage: "dice")
                }
            }
        case .starter:
            VStack(spacing: AppTheme.spacingSmall) {
                Text(selectedStarter?.name ?? "Pick from the active game")
                    .font(AppFonts.scoreSmall)
                    .multilineTextAlignment(.center)
                AppActionButton(role: .primary(tool.tint)) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        selectedStarter = activeGame?.players.randomElement()
                    }
                } label: {
                    Label("Pick Starter", systemImage: "shuffle")
                }
                .disabled(activeGame?.players.isEmpty ?? true)
            }
        case .undo:
            Label("During scoring, tap Undo Last before submitting the next round.", systemImage: "arrow.uturn.backward")
                .font(AppFonts.body)
        }
    }
}
