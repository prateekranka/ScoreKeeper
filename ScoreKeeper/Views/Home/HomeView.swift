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
    @State private var pendingDeletionID: PersistentIdentifier?
    @State private var showDeleteConfirmation = false
    @State private var saveError: String?
    @Query(filter: #Predicate<GameSession> { !$0.isComplete },
           sort: \GameSession.createdAt, order: .reverse)
    private var inProgressGames: [GameSession]
    @Query(filter: #Predicate<GameSession> { $0.isComplete },
           sort: \GameSession.createdAt, order: .reverse)
    private var completedGames: [GameSession]

    private var headerSubtitle: String {
        if inProgressGames.count == 1, let activeGame = inProgressGames.first {
            return "Round \(activeGame.currentRoundNumber) is waiting."
        }
        if inProgressGames.count > 1 {
            return "\(inProgressGames.count) active games are waiting."
        }
        return completedGames.isEmpty ? "Ready to play?" : completedGames.count.quantityText("completed game")
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

                if !inProgressGames.isEmpty {
                    HomeActiveGamesSection(
                        sessions: inProgressGames,
                        onGameTap: { router.push(.scoring($0.persistentModelID)) },
                        onDelete: requestDelete
                    )
                    .staggeredEntrance(visible: sectionsVisible, index: 1)

                    NewGameButton(action: { router.push(.gamePicker) })
                    .staggeredEntrance(visible: sectionsVisible, index: 2)
                } else if completedGames.isEmpty {
                    HomeEmptyHero(action: { router.push(.gamePicker) })
                        .staggeredEntrance(visible: sectionsVisible, index: 1)
                } else {
                    NewGameButton(action: { router.push(.gamePicker) })
                        .staggeredEntrance(visible: sectionsVisible, index: 2)
                }

                if storeManager.shouldShowFreeGamesSignal {
                    FreeGamesNote(
                        remainingFreeGames: storeManager.remainingFreeGames,
                        onUnlock: { showPaywall = true }
                    )
                    .staggeredEntrance(visible: sectionsVisible, index: 3)
                } else if !storeManager.isUnlocked {
                    PipCountUpgradeEntry(onUpgrade: { showPaywall = true })
                        .staggeredEntrance(visible: sectionsVisible, index: 3)
                }

                if !completedGames.isEmpty {
                    HomeRecentGamesSection(
                        sessions: completedGames,
                        onGameTap: { router.push(.gameDetail($0)) },
                        onSeeAll: { router.push(.gameHistory) }
                    )
                    .staggeredEntrance(visible: sectionsVisible, index: 4)

                    HomeStatsSection(sessions: completedGames)
                        .staggeredEntrance(visible: sectionsVisible, index: 5)
                }

                HomeDashboardRow(
                    gamesCount: completedGames.count,
                    activeCount: inProgressGames.count,
                    playersCount: uniquePlayerCount
                )
                .staggeredEntrance(visible: sectionsVisible, index: 6)

                HomeQuickToolsRow(selectedTool: $selectedTool)
                    .staggeredEntrance(visible: sectionsVisible, index: 7)
            }
            .padding(AppTheme.spacingMedium)
            .padding(.bottom, 76)
        }
        .appBackground()
        .navigationTitle("")
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PipCountDock(selected: .home, onSelect: selectTab)
        }
        .sheet(item: $selectedTool) { tool in
            HomeToolSheet(tool: tool, activeGame: inProgressGames.first)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .presentationDetents([.large])
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

    private func cycleTheme() {
        withAnimation(reduceMotion ? nil : AppMotion.theme) {
            themeManager.cycle()
        }
    }

    private func revealSections() {
        sectionsVisible = true
    }

    private func selectTab(_ tab: PipCountTab) {
        switch tab {
        case .home:
            break
        case .games:
            router.push(.gamePicker)
        case .players:
            router.push(.players)
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
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("PipCount")
                        .font(.system(size: 48, weight: .black, design: .default).width(.condensed))
                        .foregroundStyle(ClubhouseTheme.ink)

                    Text("Game night, organized.")
                        .font(AppFonts.body)
                        .foregroundStyle(ClubhouseTheme.ink)

                    Text(subtitle.uppercased())
                        .columnHeaderStyle()
                        .foregroundStyle(ClubhouseTheme.blue)
                        .padding(.top, 4)
                }

                Spacer()

                Button {
                    themeTrigger &+= 1
                    onThemeTap()
                } label: {
                    Image(systemName: themeIconName)
                        .font(.title3)
                        .foregroundStyle(ClubhouseTheme.ink)
                        .frame(width: 44, height: 44)
                        .appGlass(cornerRadius: AppTheme.cornerRadiusMedium, isInteractive: true)
                }
                .accessibilityLabel("Change appearance")
                .accessibilityIdentifier("theme_button")
                .buttonStyle(PressableButtonStyle())
                .sensoryFeedback(.selection, trigger: themeTrigger)
            }
            .frame(maxWidth: .infinity)

            ZStack(alignment: .topTrailing) {
                BauhausHalftone(color: ClubhouseTheme.ink)
                    .frame(width: 120, height: 92)
                    .offset(x: -32, y: 32)

                BauhausBlocksArtwork()
                    .frame(height: 184)

                BauhausStarburst(color: ClubhouseTheme.blue, size: 34)
                    .offset(x: -156, y: 8)
            }
            .frame(height: 184)
        }
        .padding(.top, AppTheme.spacingSmall)
    }
}

private struct HomeEmptyHero: View {
    let action: () -> Void

    var body: some View {
        HStack(spacing: AppTheme.spacingMedium) {
            VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                Text("No active game")
                    .font(AppFonts.title)
                    .foregroundStyle(ClubhouseTheme.ink)

                Text("Start something new or bring your regular crew back to the table.")
                    .font(AppFonts.body)
                    .foregroundStyle(ClubhouseTheme.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)

                NewGameButton(action: action)
                    .padding(.top, 4)
            }

            ZStack {
                Circle()
                    .fill(ClubhouseTheme.yellow)
                    .frame(width: 64, height: 64)
                    .offset(x: 18, y: -32)
                BauhausPlayerShape(colorIndex: 0, size: 82)
                BauhausPlayerShape(colorIndex: 1, size: 44)
                    .offset(x: 42, y: 30)
                BauhausPlayerShape(colorIndex: 3, size: 34)
                    .offset(x: -8, y: 48)
            }
            .frame(width: 112, height: 132)
            .accessibilityHidden(true)
        }
        .padding(AppTheme.spacingMedium)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge, isInteractive: true)
    }
}

private struct NewGameButton: View {
    let action: () -> Void

    var body: some View {
        AppActionButton(role: .primary(ClubhouseTheme.felt), action: action) {
            Label("New Game", systemImage: "plus.circle.fill")
        }
        .accessibilityIdentifier("new_game_button")
    }
}

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
                .font(AppFonts.caption)
                .foregroundStyle(ClubhouseTheme.brass)
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
                .foregroundStyle(ClubhouseTheme.brass)
                .frame(minHeight: 44)
                .accessibilityLabel("Upgrade to PipCount Pro")
                .accessibilityIdentifier("home_upgrade_button")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HomeActiveGamesSection: View {
    let sessions: [GameSession]
    let onGameTap: (GameSession) -> Void
    let onDelete: (GameSession) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            HStack {
                Text("Active Games")
                    .columnHeaderStyle()
                    .accessibilityIdentifier("active_games_list")
                Spacer()
                Text("\(sessions.count)")
                    .font(AppFonts.caption)
                    .monospacedDigit()
                    .foregroundStyle(ClubhouseTheme.felt)
                    .accessibilityLabel("\(sessions.count) active games")
            }

            VStack(spacing: AppTheme.spacingSmall) {
                ForEach(sessions) { session in
                    HStack(spacing: AppTheme.spacingSmall) {
                        Button {
                            onGameTap(session)
                        } label: {
                            ActiveGameRow(session: session)
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

private struct ActiveGameRow: View {
    let session: GameSession

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            HStack {
                Label(session.gameType.displayName, systemImage: session.gameType.icon)
                    .font(AppFonts.headline)
                    .foregroundStyle(ClubhouseTheme.ink)
                Spacer()
                Label("Resume", systemImage: "play.fill")
                    .font(AppFonts.caption)
                    .foregroundStyle(ClubhouseTheme.felt)
            }

            HStack(spacing: AppTheme.spacingSmall) {
                Text(session.players.count.quantityText("player"))
                Text("/")
                    .foregroundStyle(ClubhouseTheme.inkMuted)
                Text("Round \(session.currentRoundNumber)")
            }
            .font(AppFonts.body)
            .foregroundStyle(ClubhouseTheme.inkMuted)

            VStack(spacing: 0) {
                ForEach(Array(session.players.prefix(4).enumerated()), id: \.element.id) { _, player in
                    LedgerRow(
                        player: player,
                        score: player.totalScore(in: session),
                        isLeader: false
                    )
                }
            }
        }
        .padding(AppTheme.spacingMedium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge, isInteractive: true)
    }
}

private struct HomeDashboardRow: View {
    let gamesCount: Int
    let activeCount: Int
    let playersCount: Int

    var body: some View {
        HStack(spacing: 0) {
            HomeMetric(title: "Games", value: gamesCount, tint: ClubhouseTheme.brass)
            dashboardDivider
            HomeMetric(title: "Active", value: activeCount, tint: ClubhouseTheme.felt)
            dashboardDivider
            HomeMetric(title: "Players", value: playersCount, tint: PlayerColors.palette[1])
        }
        .padding(.vertical, AppTheme.spacingSmall)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusMedium)
    }

    private var dashboardDivider: some View {
        Rectangle()
            .fill(ClubhouseTheme.rule)
            .frame(width: 1, height: 40)
    }
}

private struct HomeMetric: View {
    let title: String
    let value: Int
    let tint: Color

    var body: some View {
        VStack(spacing: 3) {
            Text("\(value)")
                .font(.title2.weight(.bold))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(value)))
                .foregroundStyle(ClubhouseTheme.ink)

            HStack(spacing: 5) {
                Circle()
                    .fill(tint)
                    .frame(width: 6, height: 6)
                    .accessibilityHidden(true)

                Text(title)
                    .font(AppFonts.caption)
                    .foregroundStyle(ClubhouseTheme.inkMuted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

private struct HomeQuickToolsRow: View {
    @Binding var selectedTool: HomeTool?

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            Text("Game Night Tools")
                .columnHeaderStyle()

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
                    .background(ClubhouseTheme.paperCard.opacity(0.74), in: Circle())
                    .overlay { Circle().stroke(ClubhouseTheme.rule, lineWidth: 1) }
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
                    Text("Resume Game")
                        .font(AppFonts.title)
                        .foregroundStyle(ClubhouseTheme.ink)
                    Spacer()
                    Label("Resume", systemImage: "play.fill")
                        .font(AppFonts.headline)
                        .foregroundStyle(ClubhouseTheme.onFelt)
                        .padding(.horizontal, AppTheme.spacingMedium)
                        .frame(minHeight: 44)
                        .background(ClubhouseTheme.felt, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
                }

                HStack(spacing: AppTheme.spacingSmall) {
                    Image(systemName: session.gameType.icon)
                        .foregroundStyle(session.gameType.color)
                    Text(session.gameType.displayName)
                        .font(AppFonts.body)
                    Text("/").foregroundStyle(ClubhouseTheme.inkMuted)
                    Text(session.players.count.quantityText("player"))
                        .font(AppFonts.body)
                        .foregroundStyle(ClubhouseTheme.inkMuted)
                    Text("/").foregroundStyle(ClubhouseTheme.inkMuted)
                    Text("Round \(session.currentRoundNumber)")
                        .font(AppFonts.body)
                        .foregroundStyle(ClubhouseTheme.inkMuted)
                }

                VStack(spacing: 0) {
                    ForEach(Array(session.players.prefix(4).enumerated()), id: \.element.id) { _, player in
                        LedgerRow(
                            player: player,
                            score: player.totalScore(in: session),
                            isLeader: false
                        )
                    }
                }
            }
            .padding(AppTheme.spacingMedium)
            .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge, isInteractive: true)
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
                Text("Recent Games")
                    .columnHeaderStyle()
                Spacer()
                if !sessions.isEmpty {
                    Button("See All", action: onSeeAll)
                        .font(AppFonts.body)
                        .foregroundStyle(ClubhouseTheme.felt)
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
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(session.gameType.displayName)
                        .font(AppFonts.headline)
                        .foregroundStyle(ClubhouseTheme.ink)
                    Spacer()
                    StampBadge(text: "Final")
                }

                if let resultText {
                    Text(resultText)
                        .font(AppFonts.caption)
                        .foregroundStyle(ClubhouseTheme.brass)
                } else {
                    Text(session.players.count.quantityText("player"))
                        .font(AppFonts.caption)
                        .foregroundStyle(ClubhouseTheme.inkMuted)
                }
            }

            Spacer()

            if let date = session.completedAt {
                Text(date, style: .date)
                    .columnHeaderStyle()
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(AppTheme.spacingSmall)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusSmall, isInteractive: true)
        .rotationEffect(.degrees(session.id.uuidString.hashValue.isMultiple(of: 2) ? 0.7 : -0.7))
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
            Text("Stats")
                .columnHeaderStyle()

            Button {
                router.push(.headToHead)
            } label: {
                QuietLinkRow(title: "Head to Head", systemImage: "person.2.slash")
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

private struct QuietLinkRow: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack {
            Label(title, systemImage: systemImage)
                .font(AppFonts.body)
                .foregroundStyle(ClubhouseTheme.ink)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(ClubhouseTheme.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, AppTheme.spacingSmall)
        .overlay(alignment: .bottom) {
            Rectangle().fill(ClubhouseTheme.rule).frame(height: 1)
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
                    .font(.system(size: 52, weight: .semibold, design: .default))
                    .foregroundStyle(tool.tint)
                    .frame(width: 96, height: 96)
                    .background(ClubhouseTheme.paperSunken, in: Circle())
                    .overlay { Circle().stroke(ClubhouseTheme.rule, lineWidth: 1) }
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

// MARK: - Player Library

struct SavedPlayersView: View {
    @Environment(NavigationRouter.self) private var router
    @Query(sort: \SavedPlayer.lastUsed, order: .reverse) private var savedPlayers: [SavedPlayer]
    @State private var contentVisible = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.spacingLarge) {
                HStack(alignment: .top, spacing: AppTheme.spacingMedium) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Players")
                            .font(.system(size: 52, weight: .black, design: .default).width(.condensed))
                            .foregroundStyle(ClubhouseTheme.ink)

                        Text("Your game-night roster.")
                            .font(AppFonts.body)
                            .foregroundStyle(ClubhouseTheme.inkMuted)
                    }

                    Spacer()

                    ZStack {
                        Circle()
                            .stroke(ClubhouseTheme.ruleStrong, lineWidth: 1)
                            .frame(width: 96, height: 96)
                        BauhausPlayerShape(colorIndex: 2, size: 46)
                            .offset(x: -22, y: 14)
                        BauhausPlayerShape(colorIndex: 0, size: 56)
                            .offset(x: 18, y: 12)
                        BauhausStarburst(color: ClubhouseTheme.red, size: 30)
                            .offset(x: 31, y: -34)
                    }
                    .frame(width: 112, height: 112)
                }
                .staggeredEntrance(visible: contentVisible, index: 0)

                Text("Saved players")
                    .columnHeaderStyle()
                    .foregroundStyle(ClubhouseTheme.blue)

                if savedPlayers.isEmpty {
                    VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                        Text("No players saved yet")
                            .font(AppFonts.title)
                            .foregroundStyle(ClubhouseTheme.ink)
                        Text("Players are saved automatically after you start your first game.")
                            .font(AppFonts.body)
                            .foregroundStyle(ClubhouseTheme.inkMuted)
                    }
                    .padding(AppTheme.spacingLarge)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge)
                    .staggeredEntrance(visible: contentVisible, index: 1)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(savedPlayers.enumerated()), id: \.element.persistentModelID) { index, player in
                            HStack(spacing: AppTheme.spacingMedium) {
                                BauhausPlayerShape(colorIndex: player.colorIndex, size: 40)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(player.name)
                                        .font(AppFonts.headline)
                                        .foregroundStyle(ClubhouseTheme.ink)
                                    Text(player.gamesPlayed.quantityText("game"))
                                        .font(AppFonts.caption)
                                        .foregroundStyle(ClubhouseTheme.inkMuted)
                                }

                                Spacer()

                                Image(systemName: "circle.grid.3x3.fill")
                                    .foregroundStyle(ClubhouseTheme.ink.opacity(0.34))
                                    .accessibilityHidden(true)
                            }
                            .padding(.horizontal, AppTheme.spacingMedium)
                            .frame(minHeight: 68)
                            .overlay(alignment: .bottom) {
                                if index < savedPlayers.count - 1 {
                                    Rectangle()
                                        .fill(ClubhouseTheme.rule)
                                        .frame(height: 1)
                                }
                            }
                        }
                    }
                    .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge)
                    .staggeredEntrance(visible: contentVisible, index: 1)
                }

                AppActionButton(role: .primary(ClubhouseTheme.blue)) {
                    router.goHome()
                    router.push(.gamePicker)
                } label: {
                    Label("Start a new game", systemImage: "arrow.right")
                }
                .staggeredEntrance(visible: contentVisible, index: 2)
            }
            .padding(AppTheme.spacingMedium)
            .padding(.bottom, 76)
        }
        .appBackground()
        .navigationTitle("")
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PipCountDock(selected: .players, onSelect: selectTab)
        }
        .onAppear {
            contentVisible = true
        }
    }

    private func selectTab(_ tab: PipCountTab) {
        switch tab {
        case .home:
            router.goHome()
        case .games:
            router.goHome()
            router.push(.gamePicker)
        case .players:
            break
        case .more:
            router.push(.legalSupport)
        }
    }
}
