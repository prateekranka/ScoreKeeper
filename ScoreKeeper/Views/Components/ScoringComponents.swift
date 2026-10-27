import SwiftUI
import SwiftData

private struct PipCountEndGameKey: EnvironmentKey {
    static let defaultValue: @MainActor @Sendable () -> Void = {}
}

extension EnvironmentValues {
    var pipCountEndGame: @MainActor @Sendable () -> Void {
        get { self[PipCountEndGameKey.self] }
        set { self[PipCountEndGameKey.self] = newValue }
    }
}

enum ScoringHeaderStyle {
    case hero
    case compact
}

struct ScoringScreenLayout<Content: View, Footer: View>: View {
    let session: GameSession
    let engine: GameEngine
    let actionTitle: String
    let actionSystemImage: String?
    var showsScoreboardHeader = true
    var headerStyle: ScoringHeaderStyle = .hero
    var showsToolsBar = true
    let action: () -> Void
    @ViewBuilder var content: Content
    @ViewBuilder var footer: Footer

    @Environment(\.pipCountUsesIsland) private var usesIsland
    @Environment(\.pipCountEndGame) private var endGame
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedTool: ScoringTool?
    @State private var undoTrigger = 0
    @State private var saveError: String?
    @State private var isActionLocked = false
    @State private var actionUnlockTask: Task<Void, Never>?
    @State private var contentVisible = false

    private var bottomBarContentInset: CGFloat {
        headerStyle == .compact ? 150 : 176
    }

    var body: some View {
        GeometryReader { proxy in
            if usesIsland {
                ScrollView {
                    VStack(spacing: AppTheme.spacingMedium) {
                        scoringHeader(availableWidth: proxy.size.width)
                        responsiveContent(availableWidth: proxy.size.width)
                            .padding(.horizontal, AppTheme.spacingMedium)
                            .pipCountPageContent(maxWidth: 980)
                    }
                    .padding(.bottom, AppTheme.spacingLarge)
                    .pipCountScrollContent()
                }
                .accessibilityIdentifier("scoring_content_scroll")
            } else if dynamicTypeSize.isAccessibilitySize {
                ScrollView {
                    VStack(spacing: AppTheme.spacingMedium) {
                        scoringHeader(availableWidth: proxy.size.width)
                        scoringActions
                        responsiveContent(availableWidth: proxy.size.width)
                            .padding(.horizontal, AppTheme.spacingMedium)
                            .pipCountPageContent(maxWidth: 980)
                    }
                    .padding(.bottom, AppTheme.spacingLarge)
                }
                .accessibilityIdentifier("scoring_accessible_scroll")
            } else {
                VStack(spacing: 0) {
                    scoringHeader(availableWidth: proxy.size.width)

                    ScrollView {
                        responsiveContent(availableWidth: proxy.size.width)
                            .padding(.horizontal, AppTheme.spacingMedium)
                            .padding(.top, AppTheme.spacingSmall)
                            .padding(.bottom, bottomBarContentInset)
                            .pipCountPageContent(maxWidth: 980)
                    }
                    .safeAreaInset(edge: .bottom) {
                        scoringActions
                    }
                }
            }
        }
        .pipCountIsland {
            PipCountBackButton()
            PipCountIslandButton(title: actionTitle, systemImage: actionSystemImage ?? "plus", identifier: "submit_round_button", isSelected: true, action: performAction)
                .disabled(isActionLocked)
            PipCountIslandButton(title: "undo", systemImage: "arrow.uturn.backward", identifier: "undo_last_round_button") {
                if undoLastRound() { undoTrigger &+= 1 }
            }
            .disabled(session.sortedRounds.isEmpty)
            .sensoryFeedback(.warning, trigger: undoTrigger)
            PipCountIslandButton(title: "round log", systemImage: "list.bullet", identifier: "round_log_button") {
                selectedTool = .log
            }
            Menu {
                ForEach(ScoringTool.allCases.filter { $0 != .log }) { tool in
                    Button(tool.title, systemImage: tool.systemImage) { selectedTool = tool }
                }
                Button("end game", systemImage: "flag.checkered", role: .destructive, action: endGame)
                    .accessibilityIdentifier("end_game_button")
            } label: {
                PipCountIslandLabel(title: "Tools", systemImage: "ellipsis")
            }
            .accessibilityLabel("Tools")
            .accessibilityIdentifier("scoring_tools_button")
        }
        .sheet(item: $selectedTool) { tool in
            ScoringToolSheet(tool: tool, session: session)
                .presentationDetents(dynamicTypeSize.isAccessibilitySize || usesIsland ? [.large] : [.medium, .large])
        }
        .alert(
            "couldn’t update rounds",
            isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )
        ) {
            Button("ok", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "please try again")
        }
        .onAppear { contentVisible = true }
        .onDisappear { actionUnlockTask?.cancel() }
    }

    @ViewBuilder
    private func scoringHeader(availableWidth: CGFloat) -> some View {
        Group {
            if headerStyle == .compact {
                CompactScoringGameHeader(session: session, availableWidth: availableWidth)
            } else {
                ScoringGameHeader(session: session, availableWidth: availableWidth)
            }
        }
        .pipCountPageContent(maxWidth: 980)
        .pipCountRailHeader()

        if showsToolsBar && !usesIsland {
            ScoringToolsBar(session: session, selectedTool: $selectedTool)
                .pipCountPageContent(maxWidth: 980)
        }
        if showsScoreboardHeader {
            ScoreboardHeader(session: session, engine: engine)
                .pipCountPageContent(maxWidth: 980)
        }
    }

    /// Column choice follows the actual container width, not the size class:
    /// a sidebar-open iPad reports regular but its detail column is far too
    /// narrow for the 310-point footer beside the score content (PC17-005).
    @ViewBuilder
    private func responsiveContent(availableWidth: CGFloat) -> some View {
        if availableWidth >= 760 && !dynamicTypeSize.isAccessibilitySize {
            HStack(alignment: .top, spacing: AppTheme.spacingLarge) {
                content
                    .frame(maxWidth: .infinity, alignment: .top)
                    .staggeredEntrance(visible: contentVisible, index: 0)

                footer
                    .frame(width: 310, alignment: .top)
                    .staggeredEntrance(visible: contentVisible, index: 1)
            }
        } else {
            VStack(spacing: AppTheme.spacingMedium) {
                content
                    .staggeredEntrance(visible: contentVisible, index: 0)
                footer
                    .staggeredEntrance(visible: contentVisible, index: 1)
            }
        }
    }

    private var scoringActions: some View {
        glassGroup(spacing: AppTheme.spacingSmall) {
            VStack(spacing: AppTheme.spacingSmall) {
                AppActionButton(role: .primary(ClubhouseTheme.ink), action: performAction) {
                    if let actionSystemImage {
                        Label(actionTitle, systemImage: actionSystemImage)
                    } else {
                        Text(actionTitle)
                    }
                }
                .disabled(isActionLocked)
                .accessibilityIdentifier("submit_round_button")

                let utilityLayout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(spacing: AppTheme.spacingSmall))
                    : AnyLayout(HStackLayout(spacing: AppTheme.spacingSmall))
                utilityLayout {
                    Button {
                        if undoLastRound() {
                            undoTrigger &+= 1
                        }
                    } label: {
                        compactActionLabel("undo", systemImage: "arrow.uturn.backward")
                    }
                    .buttonStyle(PressableButtonStyle())
                    .disabled(session.sortedRounds.isEmpty)
                    .sensoryFeedback(.warning, trigger: undoTrigger)
                    .accessibilityIdentifier("undo_last_round_button")

                    Button {
                        selectedTool = .log
                    } label: {
                        compactActionLabel("round log", systemImage: "list.bullet")
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityIdentifier("round_log_button")
                }
            }
            .padding(.horizontal, AppTheme.spacingMedium)
            .padding(.top, AppTheme.spacingSmall)
            .padding(.bottom, AppTheme.spacingSmall)
            .appGlass(cornerRadius: AppTheme.cornerRadiusLarge, isInteractive: true)
            .padding(.horizontal, AppTheme.spacingMedium)
            .padding(.bottom, AppTheme.spacingSmall)
            .pipCountPageContent(maxWidth: AppTheme.formMaxWidth)
        }
    }

    private func compactActionLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(dynamicTypeSize.isAccessibilitySize ? .body.weight(.semibold) : AppFonts.body.weight(.semibold))
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
            .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 8 : 0)
            .foregroundStyle(ClubhouseTheme.ink)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 46)
            .background(ClubhouseTheme.paperCard, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                    .strokeBorder(ClubhouseTheme.ruleStrong, lineWidth: 1)
            }
    }

    private func performAction() {
        guard !isActionLocked else { return }

        isActionLocked = true
        action()

        actionUnlockTask?.cancel()
        actionUnlockTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            isActionLocked = false
        }
    }

    private func undoLastRound() -> Bool {
        guard let lastRound = session.sortedRounds.last else {
            return false
        }

        modelContext.delete(lastRound)
        do {
            try modelContext.save()
            return true
        } catch {
            let message = error.localizedDescription
            modelContext.rollback()
            saveError = message
            return false
        }
    }
}

// MARK: - Scoring headers

private struct CompactScoringGameHeader: View {
    let session: GameSession
    let availableWidth: CGFloat

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: AppTheme.spacingMedium) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Rectangle()
                        .fill(session.gameType.color)
                        .frame(width: 12, height: 12)
                        .rotationEffect(.degrees(45))

                    Text(session.gameType.displayName)
                        .font(AppFonts.headline)
                        .foregroundStyle(ClubhouseTheme.ink)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                }

                Text("round \(session.currentRoundNumber)")
                    .font(AppFonts.title)
                    .foregroundStyle(ClubhouseTheme.blue)
                    .monospacedDigit()
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)

            }

            Spacer(minLength: AppTheme.spacingSmall)

            // Decorative art yields at accessibility text sizes so the round
            // label stays whole (same rule the hero header and setup use).
            if !dynamicTypeSize.isAccessibilitySize {
                PipCountGeometricArtwork(scene: .scoring)
                    .frame(
                        width: availableWidth >= 700 ? 190 : 116,
                        height: availableWidth >= 700 ? 128 : 94
                    )
            }
        }
        .padding(.horizontal, AppTheme.spacingMedium)
        .padding(.top, AppTheme.spacingSmall)
        .padding(.bottom, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(session.gameType.displayName), round \(session.currentRoundNumber), \(session.players.count.quantityText("player"))")
    }
}

private struct ScoringGameHeader: View {
    let session: GameSession
    let availableWidth: CGFloat

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if availableWidth >= 760 && !dynamicTypeSize.isAccessibilitySize {
                HStack(alignment: .center, spacing: AppTheme.spacingXXLarge) {
                    headerCopy
                        .frame(maxWidth: 390, alignment: .leading)

                    PipCountGeometricArtwork(scene: .scoring)
                        .frame(maxWidth: 470)
                        .frame(height: 250)
                }
            } else {
                HStack(alignment: .center, spacing: AppTheme.spacingMedium) {
                    headerCopy
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if !dynamicTypeSize.isAccessibilitySize {
                        PipCountGeometricArtwork(scene: .scoring)
                            .frame(width: 168, height: 154)
                    }
                }
            }
        }
        .padding(.horizontal, AppTheme.spacingMedium)
        .padding(.top, AppTheme.spacingSmall)
        .padding(.bottom, 4)
        .accessibilityElement(children: .combine)
    }

    private var headerCopy: some View {
        VStack(alignment: .leading, spacing: 6) {

            Text(session.gameType.displayName)
                .font(AppFonts.hero)
                .foregroundStyle(ClubhouseTheme.ink)
                .lineLimit(2)

            Text("round \(session.currentRoundNumber)")
                .font(AppFonts.title)
                .foregroundStyle(ClubhouseTheme.blue)
                .monospacedDigit()

            HStack(spacing: 7) {
                ForEach(0..<min(session.currentRoundNumber, 6), id: \.self) { index in
                    Circle()
                        .fill(index.isMultiple(of: 2) ? ClubhouseTheme.blue : ClubhouseTheme.red)
                        .frame(width: 9, height: 9)
                }

                if session.currentRoundNumber > 6 {
                    Text("+\(session.currentRoundNumber - 6)")
                        .font(AppFonts.label.weight(.bold))
                        .foregroundStyle(ClubhouseTheme.blue)
                }
            }
        }
    }
}

// MARK: - Game-night tools

private enum ScoringTool: String, CaseIterable, Identifiable {
    case timer
    case dice
    case starter
    case log

    var id: String { rawValue }

    var title: String {
        switch self {
        case .timer: return "timer"
        case .dice: return "dice"
        case .starter: return "starter"
        case .log: return "log"
        }
    }

    var systemImage: String {
        switch self {
        case .timer: return "timer"
        case .dice: return "number.square.fill"
        case .starter: return "shuffle"
        case .log: return "list.bullet.rectangle"
        }
    }

    var tint: Color {
        switch self {
        case .timer: return ClubhouseTheme.red
        case .dice: return ClubhouseTheme.yellow
        case .starter: return ClubhouseTheme.green
        case .log: return ClubhouseTheme.blue
        }
    }
}

private struct ScoringToolsBar: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let session: GameSession
    @Binding var selectedTool: ScoringTool?

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: AppTheme.spacingSmall))
            : AnyLayout(HStackLayout(spacing: AppTheme.spacingSmall))
        layout {
            Text("round \(session.currentRoundNumber)")
                .columnHeaderStyle()
                .foregroundStyle(ClubhouseTheme.blue)
                .padding(.horizontal, 10)
                .frame(minHeight: 34)
                .overlay {
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(ClubhouseTheme.blue, lineWidth: 1.5)
                }
                .rotationEffect(.degrees(-2))
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("\(session.gameType.displayName), Round \(session.currentRoundNumber)")

            if !dynamicTypeSize.isAccessibilitySize { Spacer() }

            HStack(spacing: AppTheme.spacingSmall) {
            ForEach(ScoringTool.allCases) { tool in
                Button {
                    selectedTool = tool
                } label: {
                    Image(systemName: tool.systemImage)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(tool == .dice ? ClubhouseTheme.ink : tool.tint)
                        .frame(width: 44, height: 44)
                        .background(ClubhouseTheme.paperCard.opacity(0.76), in: Circle())
                        .overlay { Circle().stroke(ClubhouseTheme.rule, lineWidth: 1) }
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel(tool.title)
            }
            }
        }
        .padding(.horizontal, AppTheme.spacingMedium)
        .padding(.vertical, AppTheme.spacingSmall)
        .appGlass(cornerRadius: AppTheme.cornerRadiusLarge)
        .padding(.horizontal, AppTheme.spacingMedium)
        .padding(.top, AppTheme.spacingSmall)
    }
}

private struct ScoringToolSheet: View {
    let tool: ScoringTool
    let session: GameSession

    @Environment(\.pipCountUsesIsland) private var usesIsland
    @Environment(\.pipCountRailInset) private var railInset
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var dieRoll = 1
    @State private var selectedStarter: Player?
    @State private var pausedTimerSeconds = 60
    @State private var timerEndDate: Date?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: tool == .log ? AppTheme.spacingMedium : AppTheme.spacingLarge) {
                    ToolArtwork(tool: tool)
                        .frame(width: tool == .log || railInset > 0 ? 100 : 150, height: tool == .log || railInset > 0 ? 80 : 120)
                        .accessibilityHidden(true)

                    Text(tool.title)
                        .font(AppFonts.title)

                    toolContent
                }
                .frame(maxWidth: .infinity)
                .padding(AppTheme.spacingLarge)
                .pipCountPageContent(maxWidth: AppTheme.formMaxWidth)
                .pipCountScrollContent()
            }
            .accessibilityIdentifier("scoring_tool_content_scroll")
            .appBackground()
            .navigationTitle(tool.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarVisibility(usesIsland ? .hidden : .automatic, for: .navigationBar)
            .pipCountIsland {
                PipCountIslandButton(title: "done", systemImage: "xmark", identifier: "scoring_tool_done_button") { dismiss() }
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

    @ViewBuilder
    private var toolContent: some View {
        switch tool {
        case .timer:
            timerContent
        case .dice:
            VStack(spacing: AppTheme.spacingMedium) {
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
            VStack(spacing: AppTheme.spacingMedium) {
                Text(selectedStarter?.name ?? "pick from \(session.players.count.quantityText("player"))")
                    .font(AppFonts.scoreSmall)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)

                AppActionButton(role: .primary(tool.tint), action: pickStarter) {
                    Label("pick starter", systemImage: "shuffle")
                }
            }
        case .log:
            roundLog
        }
    }

    private var timerContent: some View {
        VStack(spacing: AppTheme.spacingMedium) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(formattedTimer(at: context.date))
                    .font(AppFonts.display)
                    .monospacedDigit()
                    .foregroundStyle(ClubhouseTheme.ink)
                    .contentTransition(.numericText())
            }

            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: AppTheme.spacingSmall))
                : AnyLayout(HStackLayout(spacing: AppTheme.spacingSmall))
            layout {
                timerPreset("30s", seconds: 30)
                timerPreset("1m", seconds: 60)
                timerPreset("2m", seconds: 120)
            }

            layout {
                AppActionButton(role: .primary(ClubhouseTheme.red), action: toggleTimer) {
                    Label(timerEndDate == nil ? "start" : "pause", systemImage: timerEndDate == nil ? "play.fill" : "pause.fill")
                }

                Button("reset", action: resetTimer)
                    .font(AppFonts.body.weight(.semibold))
                    .foregroundStyle(ClubhouseTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 92)
                    .frame(minHeight: 56)
                    .background(ClubhouseTheme.paperCard, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                            .strokeBorder(ClubhouseTheme.ruleStrong, lineWidth: 1)
                    }
                    .buttonStyle(PressableButtonStyle())
            }
        }
    }

    private var roundLog: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            if session.sortedRounds.isEmpty {
                VStack(spacing: AppTheme.spacingSmall) {
                    Text("no rounds yet")
                        .font(AppFonts.headline)
                        .foregroundStyle(ClubhouseTheme.ink)

                }
                .frame(maxWidth: .infinity)
                .padding(AppTheme.spacingMedium)
                .scorecardSurface(cornerRadius: AppTheme.cornerRadiusMedium)
                .accessibilityIdentifier("round_log_empty_state")
            } else {
                ForEach(session.sortedRounds.reversed().prefix(8), id: \.id) { round in
                    HStack {
                        Text("round \(round.roundNumber)")
                            .font(AppFonts.body.weight(.semibold))
                            .foregroundStyle(ClubhouseTheme.ink)
                        Spacer()
                        Text(round.entries.map(\.points).reduce(0, +), format: .number)
                            .font(AppFonts.scoreSmall)
                            .monospacedDigit()
                            .foregroundStyle(ClubhouseTheme.ink)
                    }
                    .padding(AppTheme.spacingSmall)
                    .scorecardSurface(cornerRadius: AppTheme.cornerRadiusSmall)
                }
            }
        }
    }

    private func timerPreset(_ title: String, seconds: Int) -> some View {
        Button(title) {
            pausedTimerSeconds = seconds
            timerEndDate = nil
        }
        .font(AppFonts.body.weight(.semibold))
        .frame(maxWidth: .infinity)
        .frame(minHeight: 46)
        .foregroundStyle(ClubhouseTheme.ink)
        .background(ClubhouseTheme.paperCard, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                .strokeBorder(ClubhouseTheme.rule, lineWidth: 1)
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func formattedTimer(at date: Date) -> String {
        let value = remainingTimerSeconds(at: date)
        let minutes = value / 60
        let seconds = value % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func remainingTimerSeconds(at date: Date = .now) -> Int {
        if let timerEndDate {
            return max(0, Int(timerEndDate.timeIntervalSince(date).rounded(.up)))
        }
        return pausedTimerSeconds
    }

    private func toggleTimer() {
        if timerEndDate != nil {
            pausedTimerSeconds = remainingTimerSeconds()
            timerEndDate = nil
        } else if pausedTimerSeconds > 0 {
            timerEndDate = .now.addingTimeInterval(TimeInterval(pausedTimerSeconds))
        }
    }

    private func resetTimer() {
        pausedTimerSeconds = 60
        timerEndDate = nil
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
        let nextStarter = session.players.randomElement()
        if reduceMotion {
            selectedStarter = nextStarter
        } else {
            withAnimation(AppMotion.state) { selectedStarter = nextStarter }
        }
    }
}

private struct ToolArtwork: View {
    let tool: ScoringTool

    var body: some View {
        ZStack {
            Circle()
                .stroke(ClubhouseTheme.ink.opacity(0.18), lineWidth: 1)
                .frame(width: 104, height: 104)

            Rectangle()
                .fill(tool.tint)
                .frame(width: 72, height: 72)
                .rotationEffect(.degrees(tool == .starter ? 45 : 0))

            if tool == .dice {
                Text("1–6")
                    .font(AppFonts.title)
                    .foregroundStyle(ClubhouseTheme.onYellow)
            } else {
                Image(systemName: tool.systemImage)
                    .font(.system(size: 32, weight: .bold, design: .default))
                    .foregroundStyle(tool == .timer || tool == .log ? ClubhouseTheme.onPrimary : ClubhouseTheme.ink)
            }

            BauhausStarburst(color: ClubhouseTheme.blue, size: 28)
                .offset(x: 54, y: -40)
        }
    }
}

// MARK: - Reusable scoring content

struct ScoreboardHeader: View {
    let session: GameSession
    let engine: GameEngine

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppTheme.spacingSmall) {
                ForEach(session.players, id: \.id) { player in
                    ScoreCard(
                        player: player,
                        totalScore: player.totalScore(in: session),
                        isLeading: leadingPlayers.contains(player.id)
                    )
                }
            }
            .padding(.horizontal, AppTheme.spacingMedium)
            .padding(.vertical, AppTheme.spacingSmall)
        }
        .appGlass(cornerRadius: AppTheme.cornerRadiusLarge)
        .padding(.horizontal, AppTheme.spacingMedium)
        .padding(.vertical, AppTheme.spacingSmall)
    }

    private var leadingPlayers: [UUID] {
        session.rounds.isEmpty ? [] : engine.winners(session: session)
    }
}

struct RoundBanner: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: AppTheme.spacingSmall) {
            Rectangle()
                .fill(color)
                .frame(width: 18, height: 18)
                .rotationEffect(.degrees(45))
                .accessibilityHidden(true)

            Text(title)
                .font(AppFonts.headline)
                .monospacedDigit()
                .foregroundStyle(ClubhouseTheme.ink)

            Spacer()

            Text(subtitle)
                .font(AppFonts.label)
                .foregroundStyle(ClubhouseTheme.inkMuted)
                .multilineTextAlignment(.trailing)
        }
        .padding(AppTheme.spacingMedium)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusMedium)
    }
}

struct RoundHistoryStrip: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let session: GameSession

    var body: some View {
        if !session.sortedRounds.isEmpty {
            VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                AppSectionHeader(
                    title: "rounds",
                    systemImage: "clock.arrow.circlepath"
                )

                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: AppTheme.spacingMedium) {
                        ForEach(session.sortedRounds, id: \.id) { round in
                            roundCard(round)
                        }
                    }
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: AppTheme.spacingSmall) {
                            ForEach(session.sortedRounds, id: \.id) { round in
                                roundCard(round)
                            }
                        }
                    }
                }
            }
            .padding(AppTheme.spacingMedium)
            .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge)
        }
    }

    private func roundCard(_ round: Round) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("round \(round.roundNumber)")
                .columnHeaderStyle()

            ForEach(session.players, id: \.id) { player in
                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
                    : AnyLayout(HStackLayout(spacing: 6))
                layout {
                    PlayerColorPip(colorIndex: player.colorIndex, size: 10)

                    Text(player.name)
                        .font(AppFonts.label)
                        .foregroundStyle(ClubhouseTheme.ink)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("round_history_\(round.roundNumber)_player_\(player.name)")

                    if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: AppTheme.spacingSmall) }

                    Text("\(round.entry(for: player.id)?.points ?? 0)")
                        .font(AppFonts.label.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(ClubhouseTheme.ink)
                }
            }
        }
        .padding(AppTheme.spacingSmall)
        .frame(width: dynamicTypeSize.isAccessibilitySize ? nil : 140, alignment: .leading)
        .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("round_history_\(round.roundNumber)_card")
        .background(ClubhouseTheme.paperCard, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                .strokeBorder(ClubhouseTheme.rule, lineWidth: 1)
        }
        .accessibilityLabel("Round \(round.roundNumber)")
    }
}
