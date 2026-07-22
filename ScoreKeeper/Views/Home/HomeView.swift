import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(NavigationRouter.self) private var router
    @Environment(ThemeManager.self) private var themeManager
    @Environment(StoreManager.self) private var storeManager
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTool: HomeTool?
    @State private var sectionsVisible = false
    @State private var showPaywall = false
    @State private var showPlayerRoster = false
    @State private var pendingDeletionID: PersistentIdentifier?
    @State private var showDeleteConfirmation = false
    @State private var saveError: String?
    #if DEBUG
    @ObservedObject private var tuning = PipTuning.shared
    #endif
    @Query(filter: #Predicate<GameSession> { !$0.isComplete },
           sort: \GameSession.createdAt, order: .reverse)
    private var inProgressGames: [GameSession]
    @Query(filter: #Predicate<GameSession> { $0.isComplete },
           sort: \GameSession.createdAt, order: .reverse)
    private var completedGames: [GameSession]

    private var statusLine: String? {
        if inProgressGames.count == 1, let activeGame = inProgressGames.first {
            return "Round \(activeGame.currentRoundNumber) is waiting."
        }
        if inProgressGames.count > 1 {
            return "\(inProgressGames.count) active games are waiting."
        }
        if completedGames.isEmpty {
            return "Ready to play?"
        }
        return completedGames.count.quantityText("completed game")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacingLarge) {
                BauhausHomeHeader(
                    statusLine: statusLine,
                    themeIconName: themeManager.iconName,
                    onThemeTap: cycleTheme
                )
                .staggeredEntrance(visible: sectionsVisible, index: 0)

                if let heroGame = inProgressGames.first {
                    BauhausActiveGameHeroCard(
                        session: heroGame,
                        onResume: { router.push(.scoring(heroGame.persistentModelID)) }
                    )
                    .staggeredEntrance(visible: sectionsVisible, index: 1)

                    if inProgressGames.count > 1 {
                        BauhausOtherActiveGamesSection(
                            sessions: Array(inProgressGames.dropFirst()),
                            onGameTap: { router.push(.scoring($0.persistentModelID)) },
                            onDelete: requestDelete
                        )
                        .staggeredEntrance(visible: sectionsVisible, index: 2)
                    }
                }

                BauhausNewGameButton(action: { router.push(.gamePicker) })
                    .staggeredEntrance(visible: sectionsVisible, index: inProgressGames.isEmpty ? 1 : 3)

                if storeManager.shouldShowFreeGamesSignal {
                    FreeGamesNote(
                        remainingFreeGames: storeManager.remainingFreeGames,
                        onUnlock: { showPaywall = true }
                    )
                    .staggeredEntrance(visible: sectionsVisible, index: paywallEntranceIndex)
                } else if !storeManager.isUnlocked {
                    PipCountUpgradeEntry(onUpgrade: { showPaywall = true })
                        .staggeredEntrance(visible: sectionsVisible, index: paywallEntranceIndex)
                }

                if inProgressGames.isEmpty && completedGames.isEmpty {
                    EmptyStateView(
                        title: "No games yet",
                        systemImage: "sparkles",
                        message: "Start with a scoreboard, Ten Phases, or What's for Dinner."
                    )
                    .staggeredEntrance(visible: sectionsVisible, index: emptyStateEntranceIndex)
                }

                if !completedGames.isEmpty {
                    BauhausRecentGamesSection(
                        sessions: completedGames,
                        onGameTap: { router.push(.gameDetail($0)) },
                        onSeeAll: { router.push(.gameHistory) }
                    )
                    .staggeredEntrance(visible: sectionsVisible, index: recentGamesEntranceIndex)

                    BauhausStatsHistorySection(sessions: completedGames)
                        .staggeredEntrance(visible: sectionsVisible, index: statsEntranceIndex)
                }

                HomeQuickToolsRow(
                    selectedTool: $selectedTool,
                    hasActiveGame: !inProgressGames.isEmpty
                )
                    .staggeredEntrance(visible: sectionsVisible, index: toolsEntranceIndex)
            }
            .padding(AppTheme.spacingMedium)
            #if DEBUG
            .padding(.bottom, CGFloat(tuning.homeToolsBottomClearance))
            #else
            .padding(.bottom, 96)
            #endif
        }
        .overlay(alignment: .top) {
            LinearGradient(
                colors: [
                    ClubhouseTheme.paper,
                    ClubhouseTheme.paper.opacity(0.92),
                    ClubhouseTheme.paper.opacity(0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            #if DEBUG
            .frame(height: CGFloat(tuning.homeHeaderTopMask))
            #else
            .frame(height: 56)
            #endif
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
        }
        .appBackground()
        .navigationTitle("")
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PipCountTabBar(selected: .home, onSelect: handleTabSelection)
        }
        .sheet(item: $selectedTool) { tool in
            HomeToolSheet(tool: tool, activeGame: inProgressGames.first)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showPlayerRoster) {
            PlayerRosterSheet { _ in }
        }
        .confirmationDialog(
            "Delete active game?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Game", role: .destructive) {
                deletePendingGame()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes the saved game and its rounds.")
        }
        .alert(
            "Couldn’t update games",
            isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "Please try again.")
        }
        .onAppear(perform: revealSections)
    }

    private var paywallEntranceIndex: Int {
        inProgressGames.isEmpty ? 2 : 4
    }

    private var emptyStateEntranceIndex: Int {
        paywallEntranceIndex + 1
    }

    private var recentGamesEntranceIndex: Int {
        if inProgressGames.isEmpty && completedGames.isEmpty {
            return emptyStateEntranceIndex + 1
        }
        return paywallEntranceIndex + 1
    }

    private var statsEntranceIndex: Int {
        recentGamesEntranceIndex + 1
    }

    private var toolsEntranceIndex: Int {
        if completedGames.isEmpty {
            return inProgressGames.isEmpty && completedGames.isEmpty
                ? emptyStateEntranceIndex + 1
                : paywallEntranceIndex + 1
        }
        return statsEntranceIndex + 1
    }

    private func cycleTheme() {
        withAnimation(reduceMotion ? nil : AppMotion.theme) {
            themeManager.cycle()
        }
    }

    private func revealSections() {
        sectionsVisible = true
    }

    private func handleTabSelection(_ tab: PipCountTab) {
        switch tab {
        case .home:
            break
        case .games:
            if completedGames.isEmpty && inProgressGames.isEmpty {
                router.push(.gamePicker)
            } else {
                router.push(.gameHistory)
            }
        case .players:
            showPlayerRoster = true
        case .more:
            router.push(.legalSupport)
        }
    }

    private func requestDelete(_ session: GameSession) {
        pendingDeletionID = session.persistentModelID
        showDeleteConfirmation = true
    }

    private func deletePendingGame() {
        guard let pendingDeletionID,
              let session = inProgressGames.first(where: { $0.persistentModelID == pendingDeletionID }) else {
            return
        }

        modelContext.delete(session)
        do {
            try modelContext.save()
            self.pendingDeletionID = nil
        } catch {
            let message = error.localizedDescription
            modelContext.rollback()
            saveError = message
        }
    }
}

// MARK: - Header

private struct BauhausHomeHeader: View {
    let statusLine: String?
    let themeIconName: String
    let onThemeTap: () -> Void
    @State private var themeTrigger = 0

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.spacingSmall) {
            VStack(alignment: .leading, spacing: 6) {
                Text("PipCount")
                    .font(AppFonts.largeTitle)
                    .foregroundStyle(ClubhouseTheme.ink)

                Text("Game night, organized.")
                    .font(AppFonts.body)
                    .foregroundStyle(ClubhouseTheme.ink.opacity(0.75))

                if let statusLine {
                    Text(statusLine)
                        .font(AppFonts.caption)
                        .foregroundStyle(ClubhouseTheme.inkMuted)
                }
            }

            Spacer(minLength: 0)

            ZStack(alignment: .topTrailing) {
                BauhausHeroArt(style: .home, height: 110)

                Button {
                    themeTrigger &+= 1
                    onThemeTap()
                } label: {
                    Image(systemName: themeIconName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(ClubhouseTheme.ink)
                        .frame(width: 40, height: 40)
                        .background(ClubhouseTheme.paperCard, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(ClubhouseTheme.rule, lineWidth: 1)
                        }
                }
                .accessibilityLabel("Change appearance")
                .accessibilityIdentifier("theme_button")
                .buttonStyle(PressableButtonStyle())
                .sensoryFeedback(.selection, trigger: themeTrigger)
            }
        }
        .padding(.top, 4)
    }
}

// MARK: - Active Games

private struct BauhausActiveGameHeroCard: View {
    let session: GameSession
    let onResume: () -> Void

    private var isPhase10: Bool { session.gameType == .phase10 }
    private let phase10TotalRounds = 10

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
            HStack {
                Text("Active Game")
                    .columnHeaderStyle()
                    .accessibilityIdentifier("active_games_list")
                Spacer()
                StatusPill(kind: .inProgress)
            }

            Text(session.gameType.displayName)
                .font(AppFonts.tileTitle)
                .foregroundStyle(ClubhouseTheme.ink)

            roundProgress

            BauhausActivePlayerScoresRow(session: session)

            BauhausPrimaryButton(
                title: "Resume Game",
                systemImage: "play.fill",
                action: onResume
            )
            .accessibilityIdentifier("resume_game_card")
            .accessibilityLabel("Resume \(session.gameType.displayName), round \(session.currentRoundNumber)")
        }
        .padding(AppTheme.spacingMedium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("active_game_\(session.id.uuidString)")
    }

    @ViewBuilder
    private var roundProgress: some View {
        if isPhase10 {
            VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                Text("Round \(session.currentRoundNumber) of \(phase10TotalRounds)")
                    .font(AppFonts.body)
                    .foregroundStyle(ClubhouseTheme.inkMuted)
                    .monospacedDigit()

                BauhausRoundDots(
                    current: session.currentRoundNumber,
                    total: phase10TotalRounds
                )
            }
        } else {
            Text("Round \(session.currentRoundNumber)")
                .font(AppFonts.body)
                .foregroundStyle(ClubhouseTheme.inkMuted)
                .monospacedDigit()
        }
    }
}

private struct BauhausActivePlayerScoresRow: View {
    let session: GameSession

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppTheme.spacingMedium) {
                ForEach(session.players) { player in
                    VStack(spacing: 6) {
                        PlayerShapeIcon(colorIndex: player.colorIndex, size: 32)

                        Text(player.name)
                            .font(AppFonts.caption.weight(.semibold))
                            .foregroundStyle(ClubhouseTheme.ink)
                            .lineLimit(1)

                        Text("\(player.totalScore(in: session))")
                            .font(AppFonts.scoreSmall)
                            .monospacedDigit()
                            .foregroundStyle(PlayerColors.color(for: player.colorIndex))
                    }
                    .frame(minWidth: 72)
                }
            }
            .padding(.vertical, 2)
        }
    }
}

private struct BauhausOtherActiveGamesSection: View {
    let sessions: [GameSession]
    let onGameTap: (GameSession) -> Void
    let onDelete: (GameSession) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            Text("More Active Games")
                .columnHeaderStyle()

            VStack(spacing: AppTheme.spacingSmall) {
                ForEach(sessions) { session in
                    HStack(spacing: AppTheme.spacingSmall) {
                        Button {
                            onGameTap(session)
                        } label: {
                            BauhausCompactActiveGameRow(session: session)
                        }
                        .buttonStyle(PressableButtonStyle())
                        .accessibilityIdentifier("active_game_\(session.id.uuidString)")
                        .accessibilityLabel("Resume \(session.gameType.displayName), round \(session.currentRoundNumber)")

                        Button(role: .destructive) {
                            onDelete(session)
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption.weight(.semibold))
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PressableButtonStyle())
                        .accessibilityLabel("Delete active \(session.gameType.displayName) game")
                        .accessibilityIdentifier("delete_active_game_\(session.id.uuidString)")
                    }
                }
            }
        }
    }
}

private struct BauhausCompactActiveGameRow: View {
    let session: GameSession

    var body: some View {
        HStack(spacing: AppTheme.spacingSmall) {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.gameType.displayName)
                    .font(AppFonts.headline)
                    .foregroundStyle(ClubhouseTheme.ink)

                Text("Round \(session.currentRoundNumber) · \(session.players.count.quantityText("player"))")
                    .font(AppFonts.caption)
                    .foregroundStyle(ClubhouseTheme.inkMuted)
                    .monospacedDigit()
            }

            Spacer(minLength: AppTheme.spacingSmall)

            StatusPill(kind: .inProgress)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(ClubhouseTheme.inkMuted)
        }
        .padding(AppTheme.spacingSmall)
        .frame(maxWidth: .infinity, alignment: .leading)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusSmall, isInteractive: true)
    }
}

// MARK: - Paywall Notes

private struct FreeGamesNote: View {
    let remainingFreeGames: Int
    let onUnlock: () -> Void

    var body: some View {
        HStack(spacing: AppTheme.spacingSmall) {
            Text("\(remainingFreeGames.quantityText("free game")) left")
                .font(AppFonts.caption)
                .foregroundStyle(ClubhouseTheme.inkMuted)
                .monospacedDigit()
                .accessibilityIdentifier("free_games_note")

            Button("Upgrade to PipCount Pro", action: onUnlock)
                .font(AppFonts.caption.weight(.semibold))
                .foregroundStyle(ClubhouseTheme.bauhausBlueDeep)
                .accessibilityIdentifier("home_upgrade_button")
                .accessibilityLabel("Upgrade to PipCount Pro")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PipCountUpgradeEntry: View {
    let onUpgrade: () -> Void

    var body: some View {
        HStack(spacing: AppTheme.spacingSmall) {
            Text("25 free games included")
                .font(AppFonts.caption)
                .foregroundStyle(ClubhouseTheme.inkMuted)
                .accessibilityIdentifier("home_upgrade_entry")

            Spacer(minLength: AppTheme.spacingSmall)

            Button("Upgrade to PipCount Pro", action: onUpgrade)
                .font(AppFonts.caption.weight(.semibold))
                .foregroundStyle(ClubhouseTheme.bauhausBlueDeep)
                .frame(minHeight: 44)
                .accessibilityLabel("Upgrade to PipCount Pro")
                .accessibilityIdentifier("home_upgrade_button")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Recent Games

private struct BauhausRecentGamesSection: View {
    let sessions: [GameSession]
    let onGameTap: (PersistentIdentifier) -> Void
    let onSeeAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            HStack {
                Text("Recent Games")
                    .columnHeaderStyle()
                Spacer()
                if !sessions.isEmpty {
                    Button(action: onSeeAll) {
                        HStack(spacing: 4) {
                            Text("See All")
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                        }
                        .font(AppFonts.body.weight(.semibold))
                        .foregroundStyle(ClubhouseTheme.bauhausBlue)
                    }
                    .accessibilityIdentifier("see_all_button")
                }
            }

            ForEach(sessions.prefix(5)) { session in
                Button {
                    onGameTap(session.persistentModelID)
                } label: {
                    BauhausRecentGameRow(session: session)
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
    }
}

private struct BauhausRecentGameRow: View {
    let session: GameSession

    private var resultText: String? {
        let engine = GameEngineFactory.engine(for: session.gameType)
        let winnerIDs = engine.winners(session: session)
        guard !winnerIDs.isEmpty else { return nil }

        let names = session.players
            .filter { winnerIDs.contains($0.id) }
            .map(\.name)

        return names.count == 1 ? "\(names[0]) won" : "\(names.joined(separator: " & ")) won"
    }

    var body: some View {
        HStack(spacing: AppTheme.spacingSmall) {
            VStack(alignment: .leading, spacing: 6) {
                Text(session.gameType.displayName)
                    .font(AppFonts.headline)
                    .foregroundStyle(ClubhouseTheme.ink)

                HStack(spacing: AppTheme.spacingSmall) {
                    if let date = session.completedAt {
                        Text(date, style: .date)
                            .font(AppFonts.caption)
                            .foregroundStyle(ClubhouseTheme.inkMuted)
                    }

                    Text(session.players.count.quantityText("player"))
                        .font(AppFonts.caption)
                        .foregroundStyle(ClubhouseTheme.inkMuted)
                }

                HStack(spacing: AppTheme.spacingSmall) {
                    StatusPill(kind: .completed)

                    if let resultText {
                        Text(resultText)
                            .font(AppFonts.caption.weight(.semibold))
                            .foregroundStyle(ClubhouseTheme.bauhausGreen)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: AppTheme.spacingSmall)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(ClubhouseTheme.inkMuted)
        }
        .padding(AppTheme.spacingSmall)
        .frame(maxWidth: .infinity, alignment: .leading)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusSmall, isInteractive: true)
    }
}

// MARK: - Stats & History

private struct BauhausStatsHistorySection: View {
    @Environment(NavigationRouter.self) private var router
    let sessions: [GameSession]

    private var playerNames: [String] {
        StatsCalculator.allPlayerNames(from: sessions)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            Text("Stats & History")
                .columnHeaderStyle()

            Button {
                router.push(.headToHead)
            } label: {
                BauhausStatsHistoryRow(
                    title: "Head to Head",
                    subtitle: "Compare players across every game night."
                )
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
                                    .foregroundStyle(ClubhouseTheme.ink)
                                    .padding(.horizontal, AppTheme.spacingSmall)
                                    .frame(minHeight: 42)
                                    .background(ClubhouseTheme.paperCard, in: Capsule())
                                    .overlay { Capsule().strokeBorder(ClubhouseTheme.rule, lineWidth: 1) }
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

private struct BauhausStatsHistoryRow: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: AppTheme.spacingSmall) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppFonts.headline)
                    .foregroundStyle(ClubhouseTheme.ink)
                Text(subtitle)
                    .font(AppFonts.caption)
                    .foregroundStyle(ClubhouseTheme.inkMuted)
            }

            Spacer(minLength: AppTheme.spacingSmall)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(ClubhouseTheme.bauhausBlue)
        }
        .padding(AppTheme.spacingSmall)
        .frame(maxWidth: .infinity, alignment: .leading)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusSmall, isInteractive: true)
    }
}

// MARK: - Quick Tools

private struct HomeQuickToolsRow: View {
    @Binding var selectedTool: HomeTool?
    var hasActiveGame = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            Text("Game Night Tools")
                .columnHeaderStyle()

            HStack(spacing: AppTheme.spacingSmall) {
                ForEach(HomeTool.allCases) { tool in
                    let isEnabled = tool != .undo || hasActiveGame
                    HomeToolButton(tool: tool, isEnabled: isEnabled) {
                        guard isEnabled else { return }
                        selectedTool = tool
                    }
                }
            }
        }
    }
}

private struct HomeToolButton: View {
    let tool: HomeTool
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(tool.tint.opacity(isEnabled ? 0.14 : 0.06))
                        .frame(width: 40, height: 40)
                    Image(systemName: tool.systemImage)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(isEnabled ? tool.tint : ClubhouseTheme.inkMuted.opacity(0.45))
                }

                Text(tool.title)
                    .font(AppFonts.caption)
                    .foregroundStyle(isEnabled ? ClubhouseTheme.ink : ClubhouseTheme.inkMuted.opacity(0.45))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 88)
            .opacity(isEnabled ? 1 : 0.72)
            .scorecardSurface(cornerRadius: AppTheme.cornerRadiusSmall, isInteractive: isEnabled)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!isEnabled)
        .accessibilityLabel(tool.accessibilityLabel)
        .accessibilityHint(isEnabled ? "" : "Available during an active game")
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
        case .timer: return ClubhouseTheme.bauhausBlue
        case .dice: return ClubhouseTheme.ink
        case .starter: return ClubhouseTheme.bauhausGreen
        case .undo: return ClubhouseTheme.bauhausBlue
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
    #if DEBUG
    @ObservedObject private var tuning = PipTuning.shared
    #endif

    var body: some View {
        NavigationStack {
            VStack(spacing: AppTheme.spacingLarge) {
                Image(systemName: tool.systemImage)
                    .font(.system(size: 52, weight: .semibold, design: .default))
                    .foregroundStyle(tool.tint)
                    .frame(width: 96, height: 96)
                    .background(ClubhouseTheme.paperSunken, in: Circle())
                    .overlay { Circle().stroke(ClubhouseTheme.rule, lineWidth: 1) }
                    #if DEBUG
                    .padding(.top, CGFloat(tuning.timerHeroOffsetY))
                    .scaleEffect(tuning.timerHeroScale)
                    #endif
                    .accessibilityHidden(true)

                VStack(spacing: AppTheme.spacingSmall) {
                    Text(toolTitle)
                        .font(AppFonts.title)
                    Text(toolMessage)
                        .font(AppFonts.body)
                        .foregroundStyle(ClubhouseTheme.inkMuted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                #if DEBUG
                .padding(.top, CGFloat(tuning.timerTitleGap) - AppTheme.spacingLarge)
                #endif

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
            return "Set a countdown and keep turns moving from the table."
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
            HomeTurnTimer()
        case .dice:
            VStack(spacing: AppTheme.spacingSmall) {
                Text("\(dieRoll)")
                    .font(.system(size: 72, weight: .heavy, design: .default))
                    .monospacedDigit()
                    .foregroundStyle(ClubhouseTheme.ink)
                    .contentTransition(.numericText(value: Double(dieRoll)))
                AppActionButton(role: .primary(tool.tint)) {
                    withAnimation(AppMotion.state) {
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
                    .contentTransition(.opacity)
                AppActionButton(role: .primary(tool.tint)) {
                    withAnimation(AppMotion.state) {
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

private struct HomeTurnTimer: View {
    @State private var timerSeconds = 60
    @State private var isTimerRunning = false

    var body: some View {
        VStack(spacing: AppTheme.spacingMedium) {
            Text(formattedTimer)
                .font(.system(size: 64, weight: .heavy, design: .default))
                .monospacedDigit()
                .foregroundStyle(ClubhouseTheme.ink)
                .contentTransition(.numericText(value: Double(timerSeconds)))

            HStack(spacing: AppTheme.spacingSmall) {
                timerPreset("30s", seconds: 30)
                timerPreset("1m", seconds: 60)
                timerPreset("2m", seconds: 120)
            }

            BauhausPrimaryButton(
                title: isTimerRunning ? "Pause" : "Start",
                systemImage: isTimerRunning ? "pause.fill" : "play.fill",
                fill: ClubhouseTheme.bauhausBlue
            ) {
                isTimerRunning.toggle()
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            guard isTimerRunning, timerSeconds > 0 else { return }
            timerSeconds -= 1
            if timerSeconds == 0 {
                isTimerRunning = false
            }
        }
    }

    private var formattedTimer: String {
        String(format: "%d:%02d", timerSeconds / 60, timerSeconds % 60)
    }

    private func timerPreset(_ title: String, seconds: Int) -> some View {
        Button(title) {
            isTimerRunning = false
            timerSeconds = seconds
        }
        .font(AppFonts.body)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 44)
        .foregroundStyle(ClubhouseTheme.ink)
        .background(ClubhouseTheme.paperCard, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                .strokeBorder(ClubhouseTheme.rule, lineWidth: 1)
        }
        .buttonStyle(PressableButtonStyle())
    }
}
