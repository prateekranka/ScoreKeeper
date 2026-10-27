import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.pipCountRailInset) private var railInset
    @Environment(NavigationRouter.self) private var router
    @Environment(StoreManager.self) private var storeManager
    @Environment(\.modelContext) private var modelContext

    @State private var selectedTool: HomeTool?
    @State private var startAfterToolDismissal = false
    @State private var sectionsVisible = false
    @State private var pendingDeletionID: PersistentIdentifier?
    @State private var showDeleteConfirmation = false
    @State private var saveError: String?

    @Query(filter: #Predicate<GameSession> { !$0.isComplete },
           sort: \GameSession.createdAt, order: .reverse)
    private var inProgressGames: [GameSession]

    @Query(filter: #Predicate<GameSession> { $0.isComplete },
           sort: \GameSession.createdAt, order: .reverse)
    private var completedGames: [GameSession]

    private var uniquePlayerCount: Int {
        let names = completedGames
            .flatMap(\.players)
            .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        return Set(names).count
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: AppTheme.spacingLarge) {
                    HomeHeader()
                        .pipCountRailHeader()
                        .staggeredEntrance(visible: sectionsVisible, index: 0)

                    responsiveDashboard(availableWidth: min(proxy.size.width, AppTheme.contentMaxWidth) - AppTheme.spacingMedium * 2)
                }
                .padding(.horizontal, AppTheme.spacingMedium)
                .padding(.top, AppTheme.spacingSmall)
                .padding(.bottom, AppTheme.spacingXLarge)
                .pipCountPageContent()
                .pipCountScrollContent()
            }
            .accessibilityIdentifier("home_content_scroll")
        }
        .appBackground()
        .navigationTitle("")
        .toolbar(horizontalSizeClass == .regular ? .visible : .hidden, for: .navigationBar)
        .sheet(item: $selectedTool, onDismiss: {
            if startAfterToolDismissal {
                startAfterToolDismissal = false
                startNewGame()
            }
        }) { tool in
            HomeToolSheet(tool: tool, activeGame: inProgressGames.first, onStartNewGame: { startAfterToolDismissal = true })
                .presentationDetents(dynamicTypeSize.isAccessibilitySize || railInset > 0 ? [.large] : [.medium, .large])
        }
        .confirmationDialog(
            "delete active game?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("delete game", role: .destructive) {
                deletePendingGame()
            }
            Button("cancel", role: .cancel) {}
        } message: {
            Text("this permanently removes the saved game and its rounds")
        }
        .alert(
            "couldn’t update games",
            isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )
        ) {
            Button("ok", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "please try again")
        }
        .onAppear { sectionsVisible = true }
    }

    @ViewBuilder
    private func responsiveDashboard(availableWidth: CGFloat) -> some View {
        if availableWidth >= AppTheme.formMaxWidth && !dynamicTypeSize.isAccessibilitySize {
            HStack(alignment: .top, spacing: AppTheme.spacingLarge) {
                VStack(spacing: AppTheme.spacingMedium) {
                    gameActionSection
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: AppTheme.spacingMedium) {
                    dashboardMetrics

                    HomeQuickToolsRow(selectedTool: $selectedTool)
                        .staggeredEntrance(visible: sectionsVisible, index: 5)
                }
                .frame(width: 360)
            }
        } else {
            VStack(spacing: AppTheme.spacingMedium) {
                gameActionSection

                dashboardMetrics

                HomeQuickToolsRow(selectedTool: $selectedTool)
                    .staggeredEntrance(visible: sectionsVisible, index: 5)
            }
        }
    }

    @ViewBuilder
    private var gameActionSection: some View {
        if !inProgressGames.isEmpty {
            if railInset > 0 {
                NewGameButton(action: startNewGame)
                    .staggeredEntrance(visible: sectionsVisible, index: 1)
            }
            HomeActiveGamesSection(
                sessions: inProgressGames,
                onGameTap: { router.push(.scoring($0.persistentModelID)) },
                onDelete: requestDelete
            )
            .staggeredEntrance(visible: sectionsVisible, index: 1)

            if railInset == 0 {
                NewGameButton(action: startNewGame)
                    .staggeredEntrance(visible: sectionsVisible, index: 2)
            }
        } else if completedGames.isEmpty {
            HomeEmptyHero(action: startNewGame)
                .staggeredEntrance(visible: sectionsVisible, index: 1)
        } else {
            NewGameButton(action: startNewGame)
                .staggeredEntrance(visible: sectionsVisible, index: 2)
        }
    }

    private func startNewGame() {
        guard storeManager.canStartNewGame else {
            storeManager.presentPaywall(afterPurchase: { router.push(.gamePicker) })
            return
        }
        router.push(.gamePicker)
    }

    @ViewBuilder
    private var dashboardMetrics: some View {
        if !completedGames.isEmpty || !inProgressGames.isEmpty {
            HomeDashboardRow(
                gamesCount: completedGames.count,
                activeCount: inProgressGames.count,
                playersCount: uniquePlayerCount
            )
            .staggeredEntrance(visible: sectionsVisible, index: 4)
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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.pipCountRailInset) private var railInset

    var body: some View {
        VStack(spacing: AppTheme.spacingMedium) {
            brandCopy
                .frame(maxWidth: .infinity, alignment: .leading)

            if !dynamicTypeSize.isAccessibilitySize {
                // Decorative art yields to content at accessibility text sizes,
                // so the first action card stays above the fold (dogfood pass 1).
                PipCountGeometricArtwork(scene: .home)
                    .frame(maxWidth: .infinity)
                    .frame(height: railInset > 0 ? 88 : AppTheme.heroArtHeight)
            }
        }
        .padding(.top, 2)
    }

    private var brandCopy: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text("pipcount")
                    .font(AppFonts.largeTitle)
                    .foregroundStyle(ClubhouseTheme.ink)

                BauhausStarburst(color: ClubhouseTheme.blue, size: 20)
            }

        }
    }
}

private struct HomeEmptyHero: View {
    let action: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.pipCountRailInset) private var railInset

    var body: some View {
        Group {
            if horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize {
                HStack(spacing: AppTheme.spacingLarge) {
                    copy
                    PipCountGeometricArtwork(scene: .homeEmpty)
                        .frame(width: 190, height: 190)
                }
            } else {
                VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
                    if dynamicTypeSize.isAccessibilitySize {
                        // Action first: at accessibility sizes the card copy
                        // alone fills the screen, so the primary action leads
                        // and the art (decorative) is dropped.
                        NewGameButton(action: action)
                        copy
                    } else {
                        HStack(alignment: .top, spacing: AppTheme.spacingMedium) {
                            copy
                            PipCountGeometricArtwork(scene: .homeEmpty)
                                .frame(width: railInset > 0 ? 88 : 118, height: railInset > 0 ? 94 : 138)
                        }
                        NewGameButton(action: action)
                    }
                }
            }
        }
        .padding(railInset > 0 ? AppTheme.spacingMedium : AppTheme.spacingLarge)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge, isInteractive: true)
    }

    private var copy: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            Text("no active game")
                .font(AppFonts.title)
                .foregroundStyle(ClubhouseTheme.ink)

            if horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize {
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
            Label("start new game", systemImage: "plus")
        }
        .accessibilityIdentifier("new_game_button")
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
                Text("active games")
                    .columnHeaderStyle()
                    .accessibilityIdentifier("active_games_list")
                Spacer()
                Text("\(sessions.count)")
                    .font(AppFonts.label.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(ClubhouseTheme.felt)
                    .accessibilityLabel("\(sessions.count) active games")
            }

            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(sessions) { session in
                        ActiveGameRow(
                            session: session,
                            onResume: { onGameTap(session) },
                            onDelete: { onDelete(session) }
                        )
                        // One nearly full-width card per game so the next
                        // card's edge peeks in from the right (the swipe
                        // affordance); a lone card fills the row.
                        .containerRelativeFrame(
                            .horizontal,
                            count: 8,
                            span: sessions.count > 1 ? 7 : 8,
                            spacing: 12
                        )
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
            .accessibilityIdentifier("active_games_carousel")
        }
    }
}

private struct ActiveGameRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.pipCountRailInset) private var railInset
    let session: GameSession
    let onResume: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            let headerLayout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: AppTheme.spacingSmall))
                : AnyLayout(HStackLayout())
            headerLayout {
                Text(session.gameType.displayName)
                    .font(AppFonts.title)
                    .foregroundStyle(ClubhouseTheme.ink)
                    .accessibilityIdentifier("active_title_\(session.id.uuidString)")
                if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                Text("in progress")
                    .font(AppFonts.label.weight(.bold))
                    .foregroundStyle(ClubhouseTheme.blue)
                    .padding(.horizontal, 10)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(minHeight: 30)
                    .overlay { Capsule().strokeBorder(ClubhouseTheme.blue, lineWidth: 1) }
                    .accessibilityIdentifier("active_status_\(session.id.uuidString)")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: AppTheme.spacingSmall) {
                Text(session.players.count.quantityText("player"))
                Text("/").foregroundStyle(ClubhouseTheme.inkMuted)
                Text("round \(session.currentRoundNumber)")
            }
            .font(AppFonts.body)
            .foregroundStyle(ClubhouseTheme.inkMuted)

            if railInset > 0 { resumeControls }

            VStack(spacing: 0) {
                ForEach(Array(session.players.prefix(4).enumerated()), id: \.element.id) { _, player in
                    LedgerRow(player: player, score: player.totalScore(in: session))
                }
            }

            if railInset == 0 { resumeControls }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge)
    }

    private var resumeControls: some View {
        GeometryReader { geometry in
            let availableWidth = max(0, geometry.size.width - AppTheme.spacingSmall - 44)

            HStack(spacing: AppTheme.spacingSmall) {
                ResumeGameSlider(
                    accessibilityLabel: "Resume \(session.gameType.displayName), round \(session.currentRoundNumber)",
                    accessibilityIdentifier: "active_game_\(session.id.uuidString)",
                    action: onResume
                )
                .frame(width: availableWidth)

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(.body.weight(.bold))
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
                .frame(width: 44)
            }
        }
        .frame(height: dynamicTypeSize.isAccessibilitySize ? 88 : 62)
    }

}

private struct ResumeGameSlider: View {
    let accessibilityLabel: String
    let accessibilityIdentifier: String
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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

                if !dynamicTypeSize.isAccessibilitySize {
                Text("resume game")
                    .font(AppFonts.headline)
                    .foregroundStyle(ClubhouseTheme.onPrimary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .padding(.leading, thumbDiameter + 10)
                    .padding(.trailing, 12)
                }

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
            // Higher priority than the surrounding active-games carousel so
            // sliding the thumb never scrolls the cards instead.
            .highPriorityGesture(
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
            HomeMetric(title: "games", value: gamesCount, tint: ClubhouseTheme.yellow)
            dashboardDivider
            HomeMetric(title: "active", value: activeCount, tint: ClubhouseTheme.blue)
            dashboardDivider
            HomeMetric(title: "players", value: playersCount, tint: ClubhouseTheme.red)
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
                    .font(AppFonts.label)
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
                Text("recent games")
                    .columnHeaderStyle()
                Spacer()
                if !sessions.isEmpty {
                    Button("see all", action: onSeeAll)
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var resultText: String? {
        let engine = GameEngineFactory.engine(for: session.gameType)
        let winnerIDs = engine.winners(session: session)
        guard !winnerIDs.isEmpty else { return "no winner" }

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
                        .accessibilityIdentifier("recent_game_title_\(session.gameType.rawValue)")
                    Spacer()
                }

                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 3) {
                        resultLabel
                        completedDateLabel
                    }
                } else {
                    HStack {
                        resultLabel
                        Spacer(minLength: AppTheme.spacingSmall)
                        completedDateLabel
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.body)
                .foregroundStyle(ClubhouseTheme.inkMuted)
        }
        .padding(.trailing, AppTheme.spacingSmall)
        .frame(minHeight: 76)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusSmall, isInteractive: true)
    }

    private var resultLabel: some View {
        Text(resultText ?? session.players.count.quantityText("player"))
            .font(AppFonts.label)
            .foregroundStyle(resultText == nil ? ClubhouseTheme.inkMuted : ClubhouseTheme.brass)
    }

    @ViewBuilder
    private var completedDateLabel: some View {
        if let date = session.completedAt {
            Text(date, style: .date)
                .columnHeaderStyle()
        }
    }
}

private struct HomeStatsSection: View {
    @Environment(NavigationRouter.self) private var router
    @Environment(\.pipCountRailInset) private var railInset
    let sessions: [GameSession]

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            if railInset == 0 {
                Text("stats")
                    .columnHeaderStyle()
            }

            Button {
                router.push(.headToHead)
            } label: {
                QuietLinkRow(title: "head to head", systemImage: "arrow.left.arrow.right")
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityIdentifier("head_to_head_button")

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
                .font(.body)
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var selectedTool: HomeTool?

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            Text("game night tools")
                .columnHeaderStyle()

            glassGroup(spacing: AppTheme.spacingSmall) {
                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(spacing: AppTheme.spacingSmall))
                    : AnyLayout(HStackLayout(spacing: AppTheme.spacingSmall))
                layout {
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let tool: HomeTool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: tool.systemImage)
                    .font(dynamicTypeSize.isAccessibilitySize ? .system(size: 24, weight: .semibold) : .title3.weight(.semibold))
                    .frame(width: dynamicTypeSize.isAccessibilitySize ? 44 : 38, height: dynamicTypeSize.isAccessibilitySize ? 44 : 38)
                    .background(ClubhouseTheme.paperCard.opacity(0.76), in: Circle())
                    .overlay { Circle().stroke(ClubhouseTheme.rule, lineWidth: 1) }
                    .foregroundStyle(ClubhouseTheme.ink)

                Text(tool.title)
                    .font(AppFonts.label.weight(.semibold))
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .frame(height: dynamicTypeSize.isAccessibilitySize ? nil : 88)
            .frame(minHeight: 88)
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
        case .timer: return "timer"
        case .dice: return "dice"
        case .starter: return "starter"
        case .undo: return "undo"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .timer: return "open game timer"
        case .dice: return "roll dice"
        case .starter: return "pick a random starter"
        case .undo: return "learn about undo"
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
    let onStartNewGame: () -> Void

    @Environment(\.pipCountUsesIsland) private var usesIsland
    @Environment(\.dismiss) private var dismiss
    @State private var dieRoll = 1
    @State private var selectedStarter: Player?

    var body: some View {
        NavigationStack {
            ScrollView {
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
                        .foregroundStyle(ClubhouseTheme.onButton(tool.tint))
                }
                .accessibilityHidden(true)

                VStack(spacing: AppTheme.spacingSmall) {
                    Text(tool.title)
                        .font(AppFonts.title)
                        .accessibilityIdentifier("home_tool_title")

                }

                ToolSheetContent(
                    tool: tool,
                    activeGame: activeGame,
                    onStartNewGame: onStartNewGame,
                    dieRoll: $dieRoll,
                    selectedStarter: $selectedStarter
                )

            }
            .frame(maxWidth: .infinity)
            .padding(AppTheme.spacingLarge)
            .pipCountScrollContent()
            }
            .appBackground()
            .navigationTitle(tool.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarVisibility(usesIsland ? .hidden : .automatic, for: .navigationBar)
            .pipCountIsland {
                PipCountIslandButton(title: "done", systemImage: "xmark", identifier: "home_tool_done_button") { dismiss() }
            }
            .toolbar {
                if !usesIsland {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("done") { dismiss() }
                    }
                }
            }
        }
    }

}

private struct ToolSheetContent: View {
    let tool: HomeTool
    let activeGame: GameSession?
    let onStartNewGame: () -> Void
    @Binding var dieRoll: Int
    @Binding var selectedStarter: Player?
    @Environment(NavigationRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        switch tool {
        case .timer, .undo:
            AppActionButton(role: .primary(ClubhouseTheme.blue)) {
                if let activeGame {
                    dismiss()
                    router.push(.scoring(activeGame.persistentModelID))
                } else {
                    onStartNewGame()
                    dismiss()
                }
            } label: {
                Label(activeGame == nil ? "start new game" : "resume game", systemImage: "play.fill")
            }
            .accessibilityHint(tool == .timer ? "Open the scoring tools to use the timer" : "Open scoring to undo the last round")
        case .dice:
            VStack(spacing: AppTheme.spacingSmall) {
                Text("\(dieRoll)")
                    .font(AppFonts.display)
                    .monospacedDigit()
                    .foregroundStyle(ClubhouseTheme.ink)
                    .contentTransition(.numericText(value: Double(dieRoll)))

                AppActionButton(role: .primary(tool.tint), action: rollNumber) {
                    Label("roll", systemImage: "arrow.triangle.2.circlepath")
                }
            }
        case .starter:
            VStack(spacing: AppTheme.spacingSmall) {
                Text(selectedStarter?.name ?? "pick from the active game")
                    .font(AppFonts.scoreSmall)
                    .multilineTextAlignment(.center)
                    .contentTransition(.opacity)

                AppActionButton(role: .primary(tool.tint), action: pickStarter) {
                    Label("pick starter", systemImage: "shuffle")
                }
                .disabled(activeGame?.players.isEmpty ?? true)
            }
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
    @Environment(\.pipCountRailInset) private var railInset
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
            VStack(alignment: .leading, spacing: railInset > 0 ? 12 : AppTheme.spacingLarge) {
                PlayersLibraryHero()
                    .pipCountRailHeader()
                    .staggeredEntrance(visible: contentVisible, index: 0)

                AppActionButton(role: .primary(ClubhouseTheme.blue)) {
                    showAddPlayer = true
                } label: {
                    Text("add player")
                }
                .accessibilityIdentifier("add_new_player_button")
                .staggeredEntrance(visible: contentVisible, index: 2)

                Text("saved players")
                    .columnHeaderStyle()
                    .foregroundStyle(ClubhouseTheme.blue)

                if savedPlayers.isEmpty {
                    VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                        Text("no players saved yet")
                            .font(AppFonts.title)
                            .foregroundStyle(ClubhouseTheme.ink)

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

                if !completedGames.isEmpty {
                    HomeStatsSection(sessions: completedGames)
                        .staggeredEntrance(visible: contentVisible, index: 3)
                }
            }
            .padding(.horizontal, AppTheme.spacingMedium)
            .padding(.top, AppTheme.spacingSmall)
            .padding(.bottom, AppTheme.spacingXLarge)
            .pipCountPageContent()
            .pipCountScrollContent()
        }
        .accessibilityIdentifier("players_content_scroll")
        .appBackground()
        .navigationTitle("")
        .toolbar(horizontalSizeClass == .regular ? .visible : .hidden, for: .navigationBar)
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

}

private struct PlayersLibraryHero: View {
    @Environment(\.pipCountRailInset) private var railInset
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
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    PipCountGeometricArtwork(scene: .roster)
                        .aspectRatio(170.0 / 180.0, contentMode: .fit)
                        .frame(maxWidth: railInset > 0 ? 130 : 170, maxHeight: railInset > 0 ? 140 : 180)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var copy: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            Text("players")
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
    @Environment(NavigationRouter.self) private var router
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.pipCountRailInset) private var railInset
    let player: SavedPlayer
    let index: Int

    var body: some View {
        Button {
            router.push(.playerStats(player.name))
        } label: {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                        playerName
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: AppTheme.spacingMedium) {
                            BauhausPlayerShape(colorIndex: player.colorIndex, size: 44)
                            gamesPlayed
                            Spacer(minLength: 0)
                            disclosureIndicator
                        }
                    }
                } else {
                    HStack(spacing: AppTheme.spacingMedium) {
                        BauhausPlayerShape(colorIndex: player.colorIndex, size: railInset > 0 ? 34 : 44)

                        VStack(alignment: .leading, spacing: 3) {
                            playerName
                            gamesPlayed
                        }

                        Spacer()
                        disclosureIndicator
                    }
                }
            }
            .padding(railInset > 0 ? 12 : AppTheme.spacingMedium)
            .frame(minHeight: railInset > 0 ? 68 : 78)
            .contentShape(Rectangle())
            .scorecardSurface(cornerRadius: AppTheme.cornerRadiusMedium, isInteractive: true)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityIdentifier("saved_player_\(player.name)")
    }

    private var playerName: some View {
        Text(player.displayName)
            .font(AppFonts.headline)
            .foregroundStyle(ClubhouseTheme.ink)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("saved_player_name_\(player.name)")
    }

    private var gamesPlayed: some View {
        Text(player.gamesPlayed.quantityText("game"))
            .font(AppFonts.label)
            .foregroundStyle(ClubhouseTheme.inkMuted)
    }

    private var disclosureIndicator: some View {
        Image(systemName: "chevron.right")
            .font(.body.weight(.bold))
            .foregroundStyle(ClubhouseTheme.inkMuted)
    }
}

private struct AddSavedPlayerSheet: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var savedPlayers: [SavedPlayer]

    @State private var playerName = ""
    @State private var saveError: String?
    @FocusState private var isNameFocused: Bool

    private var trimmedName: String {
        playerName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
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
                TextField("player name", text: $playerName)
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
                    Text("that name is already saved")
                        .font(AppFonts.label.weight(.semibold))
                        .foregroundStyle(ClubhouseTheme.red)
                }
            }
            .padding(AppTheme.spacingMedium)
            .navigationTitle("add player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("save") { savePlayer() }
                        .disabled(!canSave)
                        .accessibilityIdentifier("add_saved_player_save_button")
                }
            }
            .alert(
                "couldn’t save player",
                isPresented: Binding(
                    get: { saveError != nil },
                    set: { if !$0 { saveError = nil } }
                )
            ) {
                Button("ok", role: .cancel) { saveError = nil }
            } message: {
                Text(saveError ?? "please try again")
            }
            .onAppear { isNameFocused = true }
        }
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium, .large])
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
