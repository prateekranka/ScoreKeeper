import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(NavigationRouter.self) private var router
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
                HomeHeader(subtitle: headerSubtitle)
                    .staggeredEntrance(visible: sectionsVisible, index: 0)

                responsiveDashboard
            }
            .padding(.horizontal, AppTheme.spacingMedium)
            .padding(.top, AppTheme.spacingSmall)
            .pipCountPageContent()
        }
        .appBackground()
        .navigationTitle("")
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PipCountDock(selected: .home, onSelect: selectTab)
        }
        .sheet(item: $selectedTool) { tool in
            HomeToolSheet(tool: tool, activeGame: inProgressGames.first)
                .presentationDetents([.medium, .large])
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
        .onAppear { sectionsVisible = true }
    }

    @ViewBuilder
    private var responsiveDashboard: some View {
        if horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize {
            HStack(alignment: .top, spacing: AppTheme.spacingLarge) {
                VStack(spacing: AppTheme.spacingMedium) {
                    gameActionSection
                    upgradeSection
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: AppTheme.spacingMedium) {
                    HomeDashboardRow(
                        gamesCount: completedGames.count,
                        activeCount: inProgressGames.count,
                        playersCount: uniquePlayerCount
                    )
                    .staggeredEntrance(visible: sectionsVisible, index: 4)

                    HomeQuickToolsRow(selectedTool: $selectedTool)
                        .staggeredEntrance(visible: sectionsVisible, index: 5)
                }
                .frame(width: 360)
            }
        } else {
            VStack(spacing: AppTheme.spacingMedium) {
                gameActionSection
                upgradeSection

                HomeDashboardRow(
                    gamesCount: completedGames.count,
                    activeCount: inProgressGames.count,
                    playersCount: uniquePlayerCount
                )
                .staggeredEntrance(visible: sectionsVisible, index: 4)

                HomeQuickToolsRow(selectedTool: $selectedTool)
                    .staggeredEntrance(visible: sectionsVisible, index: 5)
            }
        }
    }

    @ViewBuilder
    private var gameActionSection: some View {
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
    }

    @ViewBuilder
    private var upgradeSection: some View {
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
}

// MARK: - Home hero

private struct HomeHeader: View {
    let subtitle: String

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: AppTheme.spacingMedium) {
            brandCopy
                .frame(maxWidth: .infinity, alignment: .leading)

            if horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize {
                HStack(alignment: .center, spacing: AppTheme.spacingXXLarge) {
                    VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
                        Text("Every night\nbecomes history.")
                            .font(AppFonts.hero)
                            .foregroundStyle(ClubhouseTheme.ink)

                        Text("Track any game. Add your crew. See the story build over time.")
                            .font(AppFonts.body)
                            .foregroundStyle(ClubhouseTheme.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)

                        Rectangle()
                            .fill(ClubhouseTheme.red)
                            .frame(width: 82, height: 4)
                    }
                    .frame(maxWidth: 390, alignment: .leading)

                    PipCountGeometricArtwork(scene: .home)
                        .frame(maxWidth: 520)
                        .frame(height: AppTheme.regularHeroArtHeight)
                }
            } else {
                PipCountGeometricArtwork(scene: .home)
                    .frame(maxWidth: .infinity)
                    .frame(height: dynamicTypeSize.isAccessibilitySize ? 200 : AppTheme.heroArtHeight)
            }
        }
        .padding(.top, 2)
    }

    private var brandCopy: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text("PipCount")
                    .font(AppFonts.largeTitle)
                    .foregroundStyle(ClubhouseTheme.ink)

                BauhausStarburst(color: ClubhouseTheme.blue, size: 20)
            }

            Text("Game night, organized.")
                .font(AppFonts.body)
                .foregroundStyle(ClubhouseTheme.ink)

            Text(subtitle.uppercased())
                .columnHeaderStyle()
                .foregroundStyle(ClubhouseTheme.blue)
                .padding(.top, 4)
        }
    }
}

private struct HomeEmptyHero: View {
    let action: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                HStack(spacing: AppTheme.spacingLarge) {
                    copy
                    PipCountGeometricArtwork(scene: .homeEmpty)
                        .frame(width: 190, height: 190)
                }
            } else {
                VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
                    HStack(alignment: .top, spacing: AppTheme.spacingMedium) {
                        copy
                        PipCountGeometricArtwork(scene: .homeEmpty)
                            .frame(width: 118, height: 138)
                    }

                    NewGameButton(action: action)
                }
            }
        }
        .padding(AppTheme.spacingLarge)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge, isInteractive: true)
    }

    private var copy: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            Text("No active game")
                .font(AppFonts.title)
                .foregroundStyle(ClubhouseTheme.ink)

            Text("Start something new or bring your regular crew back to the table.")
                .font(AppFonts.body)
                .foregroundStyle(ClubhouseTheme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)

            if horizontalSizeClass == .regular {
                NewGameButton(action: action)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct NewGameButton: View {
    let action: () -> Void

    var body: some View {
        AppActionButton(role: .primary(ClubhouseTheme.felt), action: action) {
            Label("Start New Game", systemImage: "plus")
        }
        .accessibilityIdentifier("new_game_button")
    }
}

// MARK: - Entitlement signal

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

            Spacer(minLength: AppTheme.spacingSmall)

            Button("Upgrade to PipCount Pro", action: onUnlock)
                .font(AppFonts.caption.weight(.bold))
                .foregroundStyle(ClubhouseTheme.brass)
                .frame(minHeight: 44)
                .accessibilityIdentifier("home_upgrade_button")
                .accessibilityLabel("Upgrade to PipCount Pro")
        }
        .padding(.horizontal, 2)
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
                .font(AppFonts.caption.weight(.bold))
                .foregroundStyle(ClubhouseTheme.brass)
                .frame(minHeight: 44)
                .accessibilityLabel("Upgrade to PipCount Pro")
                .accessibilityIdentifier("home_upgrade_button")
        }
    }
}

// MARK: - Active games

private struct HomeActiveGamesSection: View {
    let sessions: [GameSession]
    let onGameTap: (GameSession) -> Void
    let onDelete: (GameSession) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Active Games")
                    .columnHeaderStyle()
                    .accessibilityIdentifier("active_games_list")
                Spacer()
                Text("\(sessions.count)")
                    .font(AppFonts.caption.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(ClubhouseTheme.felt)
                    .accessibilityLabel("\(sessions.count) active games")
            }

            VStack(spacing: AppTheme.spacingSmall) {
                ForEach(sessions) { session in
                    ActiveGameRow(
                        session: session,
                        onResume: { onGameTap(session) },
                        onDelete: { onDelete(session) }
                    )
                }
            }
        }
    }
}

private struct ActiveGameRow: View {
    let session: GameSession
    let onResume: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(session.gameType.displayName)
                    .font(AppFonts.title)
                    .foregroundStyle(ClubhouseTheme.ink)
                Spacer()
                Text("In Progress")
                    .font(AppFonts.caption.weight(.bold))
                    .foregroundStyle(ClubhouseTheme.blue)
                    .padding(.horizontal, 10)
                    .frame(minHeight: 30)
                    .overlay { Capsule().strokeBorder(ClubhouseTheme.blue, lineWidth: 1) }
            }

            HStack(spacing: AppTheme.spacingSmall) {
                Text(session.players.count.quantityText("player"))
                Text("/").foregroundStyle(ClubhouseTheme.inkMuted)
                Text("Round \(session.currentRoundNumber)")
            }
            .font(AppFonts.body)
            .foregroundStyle(ClubhouseTheme.inkMuted)

            VStack(spacing: 0) {
                ForEach(Array(session.players.prefix(4).enumerated()), id: \.element.id) { _, player in
                    LedgerRow(player: player, score: player.totalScore(in: session))
                }
            }

            GeometryReader { geometry in
                let availableWidth = max(0, geometry.size.width - AppTheme.spacingSmall)

                HStack(spacing: AppTheme.spacingSmall) {
                    ResumeGameSlider(
                        accessibilityLabel: "Resume \(session.gameType.displayName), round \(session.currentRoundNumber)",
                        accessibilityIdentifier: "active_game_\(session.id.uuidString)",
                        action: onResume
                    )
                    .frame(width: availableWidth * 0.95)

                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(ClubhouseTheme.red)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(
                                ClubhouseTheme.paperSunken,
                                in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                                    .strokeBorder(ClubhouseTheme.rule, lineWidth: 1)
                            }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityLabel("Delete active \(session.gameType.displayName) game")
                    .accessibilityIdentifier("delete_active_game_\(session.id.uuidString)")
                    .frame(width: availableWidth * 0.05)
                }
            }
            .frame(height: 62)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge)
    }
}

private struct ResumeGameSlider: View {
    let accessibilityLabel: String
    let accessibilityIdentifier: String
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragOffset: CGFloat = 0

    private let thumbDiameter: CGFloat = 50
    private let thumbInset: CGFloat = 6

    var body: some View {
        GeometryReader { geometry in
            let maximumOffset = max(0, geometry.size.width - thumbDiameter - (thumbInset * 2))

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                    .fill(ClubhouseTheme.blue)

                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                    .fill(ClubhouseTheme.paperCard.opacity(0.16))
                    .frame(width: thumbDiameter + thumbInset + dragOffset)

                Text("Slide to Resume Game")
                    .font(AppFonts.headline)
                    .foregroundStyle(ClubhouseTheme.onPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .frame(maxWidth: .infinity)
                    .padding(.leading, thumbDiameter + 10)
                    .padding(.trailing, 12)

                Circle()
                    .fill(ClubhouseTheme.paperCard)
                    .frame(width: thumbDiameter, height: thumbDiameter)
                    .overlay {
                        Image(systemName: "arrow.right")
                            .font(.headline.weight(.black))
                            .foregroundStyle(ClubhouseTheme.blue)
                    }
                    .offset(x: thumbInset + dragOffset)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { value in
                        dragOffset = min(max(value.translation.width, 0), maximumOffset)
                    }
                    .onEnded { _ in
                        if maximumOffset > 0, dragOffset >= maximumOffset * 0.85 {
                            dragOffset = 0
                            action()
                        } else if reduceMotion {
                            dragOffset = 0
                        } else {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                dragOffset = 0
                            }
                        }
                    }
            )
        }
        .accessibilityRepresentation {
            Button(accessibilityLabel, action: action)
                .accessibilityHint("Resumes the saved game")
                .accessibilityIdentifier(accessibilityIdentifier)
        }
    }
}

// MARK: - Dashboard, history, stats

private struct HomeDashboardRow: View {
    let gamesCount: Int
    let activeCount: Int
    let playersCount: Int

    var body: some View {
        HStack(spacing: 0) {
            HomeMetric(title: "Games", value: gamesCount, tint: ClubhouseTheme.yellow)
            dashboardDivider
            HomeMetric(title: "Active", value: activeCount, tint: ClubhouseTheme.blue)
            dashboardDivider
            HomeMetric(title: "Players", value: playersCount, tint: ClubhouseTheme.red)
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
                .font(.title2.weight(.black))
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

struct HomeRecentGamesSection: View {
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
                        .font(AppFonts.body.weight(.semibold))
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
            Rectangle()
                .fill(session.gameType.color)
                .frame(width: 6)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(session.gameType.displayName)
                        .font(AppFonts.headline)
                        .foregroundStyle(ClubhouseTheme.ink)
                    Spacer()
                    StampBadge(text: "Final")
                }

                Text(resultText ?? session.players.count.quantityText("player"))
                    .font(AppFonts.caption)
                    .foregroundStyle(resultText == nil ? ClubhouseTheme.inkMuted : ClubhouseTheme.brass)
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
        .padding(.trailing, AppTheme.spacingSmall)
        .frame(minHeight: 76)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusSmall, isInteractive: true)
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
                QuietLinkRow(title: "Head to Head", systemImage: "arrow.left.arrow.right")
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityIdentifier("head_to_head_button")

            if !playerNames.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppTheme.spacingSmall) {
                        ForEach(Array(playerNames.enumerated()), id: \.element) { index, name in
                            Button {
                                router.push(.playerStats(name))
                            } label: {
                                HStack(spacing: 7) {
                                    PlayerColorPip(colorIndex: index, size: 14)
                                    Text(name)
                                }
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
        .padding(AppTheme.spacingMedium)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge)
    }
}

private struct QuietLinkRow: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack {
            Label(title, systemImage: systemImage)
                .font(AppFonts.body.weight(.semibold))
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

// MARK: - Home tools

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
                    .font(.title3.weight(.semibold))
                    .frame(width: 38, height: 38)
                    .background(ClubhouseTheme.paperCard.opacity(0.76), in: Circle())
                    .overlay { Circle().stroke(ClubhouseTheme.rule, lineWidth: 1) }
                    .foregroundStyle(tool.tint)

                Text(tool.title)
                    .font(AppFonts.caption.weight(.semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 88)
            .padding(.horizontal, 4)
            .appGlass(cornerRadius: AppTheme.cornerRadiusSmall, isInteractive: true)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(tool.accessibilityLabel)
    }
}

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
        case .dice: return "number.square.fill"
        case .starter: return "shuffle"
        case .undo: return "arrow.uturn.backward.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .timer: return ClubhouseTheme.red
        case .dice: return ClubhouseTheme.yellow
        case .starter: return ClubhouseTheme.green
        case .undo: return ClubhouseTheme.blue
        }
    }
}

private struct HomeToolSheet: View {
    let tool: HomeTool
    let activeGame: GameSession?

    @Environment(\.dismiss) private var dismiss
    @State private var dieRoll = 1
    @State private var selectedStarter: Player?

    var body: some View {
        NavigationStack {
            VStack(spacing: AppTheme.spacingLarge) {
                ZStack {
                    Circle()
                        .stroke(ClubhouseTheme.ink.opacity(0.16), lineWidth: 1)
                        .frame(width: 118, height: 118)

                    Rectangle()
                        .fill(tool.tint)
                        .frame(width: 72, height: 72)
                        .rotationEffect(.degrees(tool == .starter ? 45 : 0))

                    Image(systemName: tool.systemImage)
                        .font(.system(size: 34, weight: .bold, design: .default))
                        .foregroundStyle(tool == .dice ? ClubhouseTheme.ink : ClubhouseTheme.onPrimary)
                }
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

                ToolSheetContent(
                    tool: tool,
                    activeGame: activeGame,
                    dieRoll: $dieRoll,
                    selectedStarter: $selectedStarter
                )

                Spacer()
            }
            .padding(AppTheme.spacingLarge)
            .appBackground()
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
        case .dice: return "Roll a quick number"
        case .starter: return "Choose who starts"
        case .undo: return "Fix mistakes safely"
        }
    }

    private var toolMessage: String {
        switch tool {
        case .timer:
            return "A visible timer reduces table drift without leaving the score sheet."
        case .dice:
            return "Use a fast 1–6 roll when a game needs a tie-breaker or random choice."
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        switch tool {
        case .timer:
            Label("Use the live scoring toolbar timer during a game.", systemImage: "timer")
                .font(AppFonts.body)
        case .dice:
            VStack(spacing: AppTheme.spacingSmall) {
                Text("\(dieRoll)")
                    .font(.system(size: 72, weight: .black, design: .default))
                    .monospacedDigit()
                    .foregroundStyle(ClubhouseTheme.ink)
                    .contentTransition(.numericText(value: Double(dieRoll)))

                AppActionButton(role: .primary(tool.tint), action: rollNumber) {
                    Label("Roll", systemImage: "arrow.triangle.2.circlepath")
                }
            }
        case .starter:
            VStack(spacing: AppTheme.spacingSmall) {
                Text(selectedStarter?.name ?? "Pick from the active game")
                    .font(AppFonts.scoreSmall)
                    .multilineTextAlignment(.center)
                    .contentTransition(.opacity)

                AppActionButton(role: .primary(tool.tint), action: pickStarter) {
                    Label("Pick Starter", systemImage: "shuffle")
                }
                .disabled(activeGame?.players.isEmpty ?? true)
            }
        case .undo:
            Label("During scoring, tap Undo Last before submitting the next round.", systemImage: "arrow.uturn.backward")
                .font(AppFonts.body)
        }
    }

    private func rollNumber() {
        let nextRoll = Int.random(in: 1...6)
        if reduceMotion {
            dieRoll = nextRoll
        } else {
            withAnimation(AppMotion.state) { dieRoll = nextRoll }
        }
    }

    private func pickStarter() {
        let nextStarter = activeGame?.players.randomElement()
        if reduceMotion {
            selectedStarter = nextStarter
        } else {
            withAnimation(AppMotion.state) { selectedStarter = nextStarter }
        }
    }
}

// MARK: - Player library

struct SavedPlayersView: View {
    @Environment(NavigationRouter.self) private var router
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query(sort: \SavedPlayer.lastUsed, order: .reverse) private var savedPlayers: [SavedPlayer]
    @Query(filter: #Predicate<GameSession> { $0.isComplete },
           sort: \GameSession.createdAt, order: .reverse)
    private var completedGames: [GameSession]
    @State private var contentVisible = false
    @State private var showAddPlayer = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.spacingLarge) {
                PlayersLibraryHero()
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
                    LazyVGrid(columns: playerColumns, spacing: AppTheme.spacingMedium) {
                        ForEach(Array(savedPlayers.enumerated()), id: \.element.persistentModelID) { index, player in
                            SavedPlayerCard(player: player, index: index)
                        }
                    }
                    .staggeredEntrance(visible: contentVisible, index: 1)
                }

                AppActionButton(role: .primary(ClubhouseTheme.blue)) {
                    showAddPlayer = true
                } label: {
                    Text("Add Player")
                }
                .accessibilityIdentifier("add_new_player_button")
                .staggeredEntrance(visible: contentVisible, index: 2)

                if !completedGames.isEmpty {
                    HomeStatsSection(sessions: completedGames)
                        .staggeredEntrance(visible: contentVisible, index: 3)
                }
            }
            .padding(.horizontal, AppTheme.spacingMedium)
            .padding(.top, AppTheme.spacingSmall)
            .padding(.bottom, 108)
            .pipCountPageContent()
        }
        .appBackground()
        .navigationTitle("")
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PipCountDock(selected: .players, onSelect: selectTab)
        }
        .sheet(isPresented: $showAddPlayer) {
            AddSavedPlayerSheet()
        }
        .onAppear { contentVisible = true }
    }

    private var playerColumns: [GridItem] {
        horizontalSizeClass == .regular
            ? [GridItem(.flexible()), GridItem(.flexible())]
            : [GridItem(.flexible())]
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

private struct PlayersLibraryHero: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                HStack(alignment: .center, spacing: AppTheme.spacingXXLarge) {
                    copy
                        .frame(maxWidth: 360, alignment: .leading)
                    PipCountGeometricArtwork(scene: .roster)
                        .frame(maxWidth: 470)
                        .frame(height: 290)
                }
            } else {
                HStack(alignment: .center, spacing: AppTheme.spacingMedium) {
                    copy
                        .frame(maxWidth: .infinity, alignment: .leading)
                    PipCountGeometricArtwork(scene: .roster)
                        .frame(width: 170, height: 180)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var copy: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            Text("Players")
                .font(AppFonts.hero)
                .foregroundStyle(ClubhouseTheme.ink)

            Rectangle()
                .fill(ClubhouseTheme.green)
                .frame(width: 82, height: 4)
                .padding(.top, 4)
        }
    }
}

private struct SavedPlayerCard: View {
    let player: SavedPlayer
    let index: Int

    var body: some View {
        HStack(spacing: AppTheme.spacingMedium) {
            BauhausPlayerShape(colorIndex: player.colorIndex, size: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(player.name)
                    .font(AppFonts.headline)
                    .foregroundStyle(ClubhouseTheme.ink)
                Text(player.gamesPlayed.quantityText("game"))
                    .font(AppFonts.caption)
                    .foregroundStyle(ClubhouseTheme.inkMuted)
            }

            Spacer()

            Text("\(index + 1)")
                .font(AppFonts.columnHeader)
                .monospacedDigit()
                .foregroundStyle(ClubhouseTheme.inkMuted)
        }
        .padding(AppTheme.spacingMedium)
        .frame(minHeight: 78)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusMedium)
    }
}

private struct AddSavedPlayerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var savedPlayers: [SavedPlayer]

    @State private var playerName = ""
    @State private var saveError: String?
    @FocusState private var isNameFocused: Bool

    private var trimmedName: String {
        playerName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isDuplicate: Bool {
        savedPlayers.contains { $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame }
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && !isDuplicate
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
                TextField("Player name", text: $playerName)
                    .font(AppFonts.headline)
                    .foregroundStyle(ClubhouseTheme.ink)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .focused($isNameFocused)
                    .padding(.horizontal, AppTheme.spacingSmall)
                    .padding(.vertical, 12)
                    .background(ClubhouseTheme.paperCard)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(ClubhouseTheme.rule).frame(height: 1)
                    }
                    .accessibilityIdentifier("add_saved_player_name_field")

                if isDuplicate {
                    Text("That name is already saved.")
                        .font(AppFonts.caption.weight(.semibold))
                        .foregroundStyle(ClubhouseTheme.red)
                }
            }
            .padding(AppTheme.spacingMedium)
            .navigationTitle("Add Player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { savePlayer() }
                        .disabled(!canSave)
                        .accessibilityIdentifier("add_saved_player_save_button")
                }
            }
            .alert(
                "Couldn’t save player",
                isPresented: Binding(
                    get: { saveError != nil },
                    set: { if !$0 { saveError = nil } }
                )
            ) {
                Button("OK", role: .cancel) { saveError = nil }
            } message: {
                Text(saveError ?? "Please try again.")
            }
            .onAppear { isNameFocused = true }
        }
        .presentationDetents([.medium])
    }

    private func savePlayer() {
        let saved = SavedPlayer(
            name: trimmedName,
            colorIndex: Int.random(in: 0..<PlayerColors.palette.count)
        )
        modelContext.insert(saved)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            saveError = error.localizedDescription
        }
    }
}
