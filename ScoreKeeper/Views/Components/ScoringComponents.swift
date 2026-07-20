import SwiftUI
import SwiftData

struct ScoringScreenLayout<Content: View, Footer: View>: View {
    let session: GameSession
    let engine: GameEngine
    let actionTitle: String
    let actionSystemImage: String?
    var showsScoreboardHeader = true
    let action: () -> Void
    @ViewBuilder var content: Content
    @ViewBuilder var footer: Footer
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTool: ScoringTool?
    @State private var undoTrigger = 0
    @State private var saveError: String?
    private let bottomBarContentInset: CGFloat = 132

    var body: some View {
        VStack(spacing: 0) {
            ScoringToolsBar(session: session, selectedTool: $selectedTool)
            if showsScoreboardHeader {
                ScoreboardHeader(session: session, engine: engine)
            }

            ScrollView {
                VStack(spacing: AppTheme.spacingMedium) {
                    content
                    footer
                }
                .padding(AppTheme.spacingMedium)
                .padding(.bottom, bottomBarContentInset)
            }
            .safeAreaInset(edge: .bottom) {
                glassGroup(spacing: AppTheme.spacingSmall) {
                    VStack(spacing: AppTheme.spacingSmall) {
                        if actionTitle == "Submit" {
                            BauhausPrimaryButton(
                                title: "Submit Round",
                                systemImage: nil,
                                fill: ClubhouseTheme.ink,
                                action: action
                            )
                            .accessibilityIdentifier("submit_round_button")
                        } else {
                            BauhausPrimaryButton(
                                title: actionTitle,
                                systemImage: actionSystemImage,
                                fill: session.gameType.color,
                                action: action
                            )
                            .accessibilityIdentifier("submit_round_button")
                        }

                        Button {
                            undoTrigger &+= 1
                            undoLastRound()
                        } label: {
                            Label("Undo Last Round", systemImage: "arrow.uturn.backward")
                                .font(AppFonts.body.weight(.semibold))
                                .foregroundStyle(ClubhouseTheme.ink)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 48)
                                .background(ClubhouseTheme.paperCard, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                                        .strokeBorder(ClubhouseTheme.ink, lineWidth: 1.5)
                                }
                        }
                        .buttonStyle(PressableButtonStyle())
                        .disabled(session.sortedRounds.isEmpty)
                        .sensoryFeedback(.warning, trigger: undoTrigger)
                        .accessibilityIdentifier("undo_last_round_button")
                    }
                    .padding(.horizontal, AppTheme.spacingMedium)
                    .padding(.top, AppTheme.spacingSmall)
                    .padding(.bottom, AppTheme.spacingSmall)
                    .appGlass(cornerRadius: AppTheme.cornerRadiusLarge, isInteractive: true)
                    .padding(.horizontal, AppTheme.spacingMedium)
                    .padding(.bottom, AppTheme.spacingSmall)
                }
            }
        }
        .sheet(item: $selectedTool) { tool in
            ScoringToolSheet(tool: tool, session: session)
                .presentationDetents([.medium])
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
    }

    private func undoLastRound() {
        guard let lastRound = session.sortedRounds.last else {
            return
        }

        modelContext.delete(lastRound)
        do {
            try modelContext.save()
        } catch {
            let message = error.localizedDescription
            modelContext.rollback()
            saveError = message
        }
    }
}

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
        case .dice: return "die.face.5.fill"
        case .starter: return "shuffle"
        case .log: return "list.bullet.rectangle"
        }
    }

    var tint: Color {
        switch self {
        case .timer: return PlayerColors.palette[1]
        case .dice: return PlayerColors.palette[4]
        case .starter: return PlayerColors.palette[3]
        case .log: return PlayerColors.palette[0]
        }
    }
}

private enum ScoringRoundProgress {
    static func knownTotalRounds(for session: GameSession) -> Int? {
        switch session.gameType {
        case .phase10:
            return 10
        case .generic, .whatsForDinner:
            return nil
        }
    }

    static func cappedDotTotal(for session: GameSession) -> Int {
        min(max(session.currentRoundNumber, 1), 10)
    }
}

private struct ScoringToolsBar: View {
    let session: GameSession
    @Binding var selectedTool: ScoringTool?

    private var knownTotal: Int? {
        ScoringRoundProgress.knownTotalRounds(for: session)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            HStack(alignment: .top, spacing: AppTheme.spacingSmall) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.gameType.displayName)
                        .font(AppFonts.headline)
                        .foregroundStyle(ClubhouseTheme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    roundLabel
                }

                Spacer(minLength: AppTheme.spacingSmall)

                Text("PipCount")
                    .font(AppFonts.caption)
                    .foregroundStyle(ClubhouseTheme.inkMuted.opacity(0.72))
                    .accessibilityHidden(true)
            }

            HStack(alignment: .center) {
                if let knownTotal {
                    BauhausRoundDots(
                        current: session.currentRoundNumber,
                        total: knownTotal
                    )
                } else {
                    BauhausRoundDots(
                        current: session.currentRoundNumber,
                        total: ScoringRoundProgress.cappedDotTotal(for: session)
                    )
                }

                Spacer(minLength: AppTheme.spacingSmall)

                HStack(spacing: 6) {
                    ForEach(ScoringTool.allCases) { tool in
                        Button {
                            selectedTool = tool
                        } label: {
                            Image(systemName: tool.systemImage)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(ClubhouseTheme.ink)
                                .frame(width: 38, height: 38)
                                .background(ClubhouseTheme.paperCard, in: Circle())
                                .overlay { Circle().stroke(ClubhouseTheme.rule, lineWidth: 1) }
                        }
                        .buttonStyle(PressableButtonStyle())
                        .accessibilityLabel(tool.title)
                    }
                }
            }
        }
        .padding(.horizontal, AppTheme.spacingMedium)
        .padding(.vertical, AppTheme.spacingSmall)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge)
        .padding(.horizontal, AppTheme.spacingMedium)
        .padding(.top, AppTheme.spacingSmall)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(scoringAccessibilityLabel)
    }

    private var roundLabel: some View {
        HStack(spacing: 4) {
            Text("Round")
                .font(AppFonts.body)
                .foregroundStyle(ClubhouseTheme.inkMuted)

            Text("\(session.currentRoundNumber)")
                .font(AppFonts.body.weight(.bold))
                .foregroundStyle(ClubhouseTheme.bauhausBlue)
                .monospacedDigit()

            if let knownTotal {
                Text("of")
                    .font(AppFonts.body)
                    .foregroundStyle(ClubhouseTheme.inkMuted)

                Text("\(knownTotal)")
                    .font(AppFonts.body.weight(.semibold))
                    .foregroundStyle(ClubhouseTheme.ink)
                    .monospacedDigit()
            }
        }
    }

    private var scoringAccessibilityLabel: String {
        if let knownTotal {
            return "\(session.gameType.displayName), Round \(session.currentRoundNumber) of \(knownTotal)"
        }
        return "\(session.gameType.displayName), Round \(session.currentRoundNumber)"
    }
}

private struct ScoringToolSheet: View {
    let tool: ScoringTool
    let session: GameSession
    @Environment(\.dismiss) private var dismiss
    @State private var dieRoll = 1
    @State private var selectedStarter: Player?
    @State private var timerSeconds = 60

    var body: some View {
        NavigationStack {
            VStack(spacing: AppTheme.spacingLarge) {
                ToolArtwork(tool: tool)
                    .frame(width: 116, height: 96)
                    .accessibilityHidden(true)

                Text(tool.title)
                    .font(AppFonts.title)

                toolContent

                Spacer()
            }
            .padding(AppTheme.spacingLarge)
            .navigationTitle(tool.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var toolContent: some View {
        switch tool {
        case .timer:
            VStack(spacing: AppTheme.spacingMedium) {
                Text(formattedTimer)
                    .font(.system(size: 64, weight: .heavy, design: .default))
                    .monospacedDigit()
                    .foregroundStyle(ClubhouseTheme.ink)

                HStack(spacing: AppTheme.spacingSmall) {
                    timerButton("30s", seconds: 30)
                    timerButton("1m", seconds: 60)
                    timerButton("2m", seconds: 120)
                }
            }
        case .dice:
            VStack(spacing: AppTheme.spacingMedium) {
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
            VStack(spacing: AppTheme.spacingMedium) {
                Text(selectedStarter?.name ?? "Pick from \(session.players.count.quantityText("player"))")
                    .font(AppFonts.scoreSmall)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)
                AppActionButton(role: .primary(tool.tint)) {
                    withAnimation(AppMotion.state) {
                        selectedStarter = session.players.randomElement()
                    }
                } label: {
                    Label("Pick Starter", systemImage: "shuffle")
                }
            }
        case .log:
            VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                if session.sortedRounds.isEmpty {
                    ContentUnavailableView("No rounds yet", systemImage: "list.bullet.rectangle")
                } else {
                    ForEach(session.sortedRounds.reversed().prefix(5), id: \.id) { round in
                        HStack {
                            Text("Round \(round.roundNumber)")
                                .font(AppFonts.body)
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
    }

    private var formattedTimer: String {
        let minutes = timerSeconds / 60
        let seconds = timerSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func timerButton(_ title: String, seconds: Int) -> some View {
        Button(title) {
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

private struct ToolArtwork: View {
    let tool: ScoringTool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                .fill(ClubhouseTheme.paperSunken)
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                        .strokeBorder(ClubhouseTheme.rule, lineWidth: 1)
                }

            if tool == .starter {
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(index == 1 ? tool.tint : ClubhouseTheme.paperCard)
                            .frame(width: index == 1 ? 34 : 24, height: index == 1 ? 34 : 24)
                            .overlay { Circle().stroke(ClubhouseTheme.rule, lineWidth: 1) }
                    }
                }
                .overlay {
                    Image(systemName: "shuffle")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(ClubhouseTheme.onFelt)
                }
            } else {
                Image(systemName: tool.systemImage)
                    .font(.system(size: 48, weight: .semibold, design: .default))
                    .foregroundStyle(tool.tint)
                    .frame(width: 72, height: 72)
                    .background(ClubhouseTheme.paperCard, in: Circle())
                    .overlay { Circle().stroke(ClubhouseTheme.rule, lineWidth: 1) }
            }
        }
    }
}

struct ScoreboardHeader: View {
    let session: GameSession
    let engine: GameEngine

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppTheme.spacingSmall) {
                ForEach(session.players, id: \.id) { player in
                    let isLeading = leadingPlayers.contains(player.id)
                    VStack(spacing: 6) {
                        PlayerShapeIcon(colorIndex: player.colorIndex, size: 28)

                        Text(player.name)
                            .font(AppFonts.caption.weight(.semibold))
                            .foregroundStyle(ClubhouseTheme.ink)
                            .lineLimit(1)

                        Text("\(player.totalScore(in: session))")
                            .font(AppFonts.scoreSmall)
                            .monospacedDigit()
                            .foregroundStyle(
                                isLeading
                                    ? ClubhouseTheme.bauhausYellow
                                    : PlayerColors.color(for: player.colorIndex)
                            )
                            .contentTransition(.numericText(value: Double(player.totalScore(in: session))))

                        if isLeading {
                            BrassCrown()
                        }
                    }
                    .padding(AppTheme.spacingSmall)
                    .frame(minWidth: 88)
                    .background(
                        isLeading ? PlayerColors.lightColor(for: player.colorIndex) : ClubhouseTheme.paperCard,
                        in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                            .strokeBorder(
                                isLeading ? ClubhouseTheme.bauhausBlue : ClubhouseTheme.rule,
                                lineWidth: isLeading ? 2 : 1
                            )
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        "\(player.name), total score \(player.totalScore(in: session))\(isLeading ? ", leading" : "")"
                    )
                }
            }
            .padding(.horizontal, AppTheme.spacingMedium)
            .padding(.vertical, AppTheme.spacingSmall)
        }
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
            Image(systemName: icon)
                .foregroundStyle(color)
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
        }
    }

    private func roundCard(_ round: Round) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Round \(round.roundNumber)")
                .columnHeaderStyle()

            ForEach(session.players, id: \.id) { player in
                HStack(spacing: 6) {
                    PlayerShapeIcon(colorIndex: player.colorIndex, size: 12)

                    Text(player.name)
                        .font(AppFonts.caption)
                        .foregroundStyle(ClubhouseTheme.ink)
                        .lineLimit(1)

                    Spacer(minLength: AppTheme.spacingSmall)

                    Text("\(round.entry(for: player.id)?.points ?? 0)")
                        .font(AppFonts.caption)
                        .monospacedDigit()
                        .foregroundStyle(ClubhouseTheme.ink)
                }
            }
        }
        .padding(AppTheme.spacingSmall)
        .frame(width: 132, alignment: .leading)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusSmall)
        .accessibilityLabel("Round \(round.roundNumber)")
    }
}
