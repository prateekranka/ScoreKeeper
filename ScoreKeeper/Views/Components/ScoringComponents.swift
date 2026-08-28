import SwiftUI
import SwiftData

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

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
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
        VStack(spacing: 0) {
            Group {
                if headerStyle == .compact {
                    CompactScoringGameHeader(session: session)
                } else {
                    ScoringGameHeader(session: session)
                }
            }
            .pipCountPageContent(maxWidth: 980)

            if showsToolsBar {
                ScoringToolsBar(session: session, selectedTool: $selectedTool)
                    .pipCountPageContent(maxWidth: 980)
            }

            if showsScoreboardHeader {
                ScoreboardHeader(session: session, engine: engine)
                    .pipCountPageContent(maxWidth: 980)
            }

            ScrollView {
                responsiveContent
                    .padding(.horizontal, AppTheme.spacingMedium)
                    .padding(.top, AppTheme.spacingSmall)
                    .padding(.bottom, bottomBarContentInset)
                    .pipCountPageContent(maxWidth: 980)
            }
            .safeAreaInset(edge: .bottom) {
                scoringActions
            }
        }
        .sheet(item: $selectedTool) { tool in
            ScoringToolSheet(tool: tool, session: session)
                .presentationDetents([.medium, .large])
        }
        .alert(
            "Couldn’t update rounds",
            isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "Please try again.")
        }
        .onAppear { contentVisible = true }
        .onDisappear { actionUnlockTask?.cancel() }
    }

    @ViewBuilder
    private var responsiveContent: some View {
        if horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize {
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

                HStack(spacing: AppTheme.spacingSmall) {
                    Button {
                        if undoLastRound() {
                            undoTrigger &+= 1
                        }
                    } label: {
                        compactActionLabel("Undo", systemImage: "arrow.uturn.backward")
                    }
                    .buttonStyle(PressableButtonStyle())
                    .disabled(session.sortedRounds.isEmpty)
                    .sensoryFeedback(.warning, trigger: undoTrigger)
                    .accessibilityIdentifier("undo_last_round_button")

                    Button {
                        selectedTool = .log
                    } label: {
                        compactActionLabel("Round Log", systemImage: "list.bullet")
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
            .font(dynamicTypeSize.isAccessibilitySize ? .caption.weight(.semibold) : AppFonts.body.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.65)
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

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

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
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Text("Round \(session.currentRoundNumber)")
                    .font(AppFonts.title)
                    .foregroundStyle(ClubhouseTheme.blue)
                    .monospacedDigit()

                Text(session.players.count.quantityText("player").uppercased())
                    .columnHeaderStyle()
            }

            Spacer(minLength: AppTheme.spacingSmall)

            PipCountGeometricArtwork(scene: .scoring)
                .frame(
                    width: horizontalSizeClass == .regular ? 190 : 116,
                    height: horizontalSizeClass == .regular ? 128 : 94
                )
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

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Group {
            if horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize {
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
            Text("PipCount")
                .font(AppFonts.headline)
                .foregroundStyle(ClubhouseTheme.ink)

            Text(session.gameType.displayName)
                .font(AppFonts.hero)
                .foregroundStyle(ClubhouseTheme.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.75)

            Text("Round \(session.currentRoundNumber)")
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
                        .font(AppFonts.caption.weight(.bold))
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
        case .timer: return "Timer"
        case .dice: return "Dice"
        case .starter: return "Starter"
        case .log: return "Log"
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
    let session: GameSession
    @Binding var selectedTool: ScoringTool?

    var body: some View {
        HStack(spacing: AppTheme.spacingSmall) {
            Text("Round \(session.currentRoundNumber)")
                .columnHeaderStyle()
                .foregroundStyle(ClubhouseTheme.blue)
                .padding(.horizontal, 10)
                .frame(minHeight: 34)
                .overlay {
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(ClubhouseTheme.blue, lineWidth: 1.5)
                }
                .rotationEffect(.degrees(-2))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .accessibilityLabel("\(session.gameType.displayName), Round \(session.currentRoundNumber)")

            Spacer()

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

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dieRoll = 1
    @State private var selectedStarter: Player?
    @State private var pausedTimerSeconds = 60
    @State private var timerEndDate: Date?

    var body: some View {
        NavigationStack {
            VStack(spacing: AppTheme.spacingLarge) {
                ToolArtwork(tool: tool)
                    .frame(width: 150, height: 120)
                    .accessibilityHidden(true)

                Text(tool.title)
                    .font(AppFonts.title)

                toolContent

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

    @ViewBuilder
    private var toolContent: some View {
        switch tool {
        case .timer:
            timerContent
        case .dice:
            VStack(spacing: AppTheme.spacingMedium) {
                Text("\(dieRoll)")
                    .font(.system(size: 76, weight: .black, design: .default))
                    .monospacedDigit()
                    .foregroundStyle(ClubhouseTheme.ink)
                    .contentTransition(.numericText(value: Double(dieRoll)))

                AppActionButton(role: .primary(tool.tint), action: rollNumber) {
                    Label("Roll", systemImage: "arrow.triangle.2.circlepath")
                }
            }
        case .starter:
            VStack(spacing: AppTheme.spacingMedium) {
                Text(selectedStarter?.name ?? "Pick from \(session.players.count.quantityText("player"))")
                    .font(AppFonts.scoreSmall)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)

                AppActionButton(role: .primary(tool.tint), action: pickStarter) {
                    Label("Pick Starter", systemImage: "shuffle")
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
                    .font(.system(size: 64, weight: .black, design: .default))
                    .monospacedDigit()
                    .foregroundStyle(ClubhouseTheme.ink)
                    .contentTransition(.numericText())
            }

            HStack(spacing: AppTheme.spacingSmall) {
                timerPreset("30s", seconds: 30)
                timerPreset("1m", seconds: 60)
                timerPreset("2m", seconds: 120)
            }

            HStack(spacing: AppTheme.spacingSmall) {
                AppActionButton(role: .primary(ClubhouseTheme.red), action: toggleTimer) {
                    Label(timerEndDate == nil ? "Start" : "Pause", systemImage: timerEndDate == nil ? "play.fill" : "pause.fill")
                }

                Button("Reset", action: resetTimer)
                    .font(AppFonts.body.weight(.semibold))
                    .foregroundStyle(ClubhouseTheme.ink)
                    .frame(width: 92, height: 56)
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
                ContentUnavailableView("No rounds yet", systemImage: "list.bullet.rectangle")
            } else {
                ForEach(session.sortedRounds.reversed().prefix(8), id: \.id) { round in
                    HStack {
                        Text("Round \(round.roundNumber)")
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
                    .font(.system(size: 24, weight: .black, design: .default))
                    .foregroundStyle(ClubhouseTheme.ink)
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
                .font(AppFonts.caption)
                .foregroundStyle(ClubhouseTheme.inkMuted)
                .multilineTextAlignment(.trailing)
        }
        .padding(AppTheme.spacingMedium)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusMedium)
    }
}

struct ScoreEntryRow<Accessory: View>: View {
    let player: Player
    @Binding var value: Int
    var range: ClosedRange<Int> = -9999...9999
    var step = 1
    var title: String?
    @ViewBuilder var accessory: Accessory

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            HStack(spacing: AppTheme.spacingSmall) {
                PlayerBadge(name: player.name, colorIndex: player.colorIndex, size: .small)
                    .layoutPriority(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                accessory
                    .fixedSize(horizontal: true, vertical: false)
            }

            HStack(alignment: .top, spacing: AppTheme.spacingSmall) {
                if let title {
                    Text(title)
                        .font(AppFonts.caption)
                        .foregroundStyle(ClubhouseTheme.inkMuted)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(1)
                }

                Spacer()

                ScoreEntryField(
                    value: $value,
                    label: "",
                    range: range,
                    step: step,
                    identifierPrefix: "\(player.name)_"
                )
                .fixedSize(horizontal: true, vertical: false)
            }
        }
        .padding(AppTheme.spacingMedium)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusMedium, isInteractive: true)
        .accessibilityElement(children: .contain)
    }
}

struct RoundHistoryStrip: View {
    let session: GameSession

    var body: some View {
        if !session.sortedRounds.isEmpty {
            VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                AppSectionHeader(
                    title: "Rounds",
                    subtitle: "\(session.sortedRounds.count) submitted",
                    systemImage: "clock.arrow.circlepath"
                )

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppTheme.spacingSmall) {
                        ForEach(session.sortedRounds, id: \.id) { round in
                            roundCard(round)
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
            Text("Round \(round.roundNumber)")
                .columnHeaderStyle()

            ForEach(session.players, id: \.id) { player in
                HStack(spacing: 6) {
                    PlayerColorPip(colorIndex: player.colorIndex, size: 10)

                    Text(player.name)
                        .font(AppFonts.caption)
                        .foregroundStyle(ClubhouseTheme.ink)
                        .lineLimit(1)

                    Spacer(minLength: AppTheme.spacingSmall)

                    Text("\(round.entry(for: player.id)?.points ?? 0)")
                        .font(AppFonts.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(ClubhouseTheme.ink)
                }
            }
        }
        .padding(AppTheme.spacingSmall)
        .frame(width: 140, alignment: .leading)
        .background(ClubhouseTheme.paperCard, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                .strokeBorder(ClubhouseTheme.rule, lineWidth: 1)
        }
        .accessibilityLabel("Round \(round.roundNumber)")
    }
}
