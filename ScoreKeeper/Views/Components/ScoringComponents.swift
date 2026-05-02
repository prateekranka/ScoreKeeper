import SwiftUI
import SwiftData

struct ScoringScreenLayout<Content: View, Footer: View>: View {
    let session: GameSession
    let engine: GameEngine
    let actionTitle: String
    let actionSystemImage: String?
    let action: () -> Void
    @ViewBuilder var content: Content
    @ViewBuilder var footer: Footer
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTool: ScoringTool?
    @State private var undoTrigger = 0

    var body: some View {
        VStack(spacing: 0) {
            ScoringToolsBar(session: session, selectedTool: $selectedTool)
            ScoreboardHeader(session: session, engine: engine)

            ScrollView {
                VStack(spacing: AppTheme.spacingMedium) {
                    content
                    footer
                }
                .padding(AppTheme.spacingMedium)
                .padding(.bottom, 76)
            }
            .safeAreaInset(edge: .bottom) {
                glassGroup(spacing: AppTheme.spacingSmall) {
                    VStack(spacing: AppTheme.spacingSmall) {
                        HStack(spacing: AppTheme.spacingSmall) {
                            Button {
                                undoTrigger &+= 1
                                undoLastRound()
                            } label: {
                                Label("Undo Last", systemImage: "arrow.uturn.backward")
                                    .font(AppFonts.body)
                                    .frame(maxWidth: .infinity)
                                    .frame(minHeight: 44)
                                    .appGlass(cornerRadius: AppTheme.cornerRadiusSmall)
                            }
                            .buttonStyle(PressableButtonStyle())
                            .disabled(session.sortedRounds.isEmpty)
                            .sensoryFeedback(.warning, trigger: undoTrigger)
                            .accessibilityIdentifier("undo_last_round_button")

                            AppActionButton(role: .primary(session.gameType.color), action: action) {
                                if let actionSystemImage {
                                    Label(actionTitle, systemImage: actionSystemImage)
                                } else {
                                    Text(actionTitle)
                                }
                            }
                            .accessibilityIdentifier("submit_round_button")
                        }
                    }
                    .padding(.horizontal, AppTheme.spacingMedium)
                    .padding(.top, AppTheme.spacingSmall)
                    .padding(.bottom, AppTheme.spacingSmall)
                    .background(.ultraThinMaterial)
                }
            }
        }
        .sheet(item: $selectedTool) { tool in
            ScoringToolSheet(tool: tool, session: session)
                .presentationDetents([.medium])
        }
    }

    private func undoLastRound() {
        guard let lastRound = session.sortedRounds.last else {
            return
        }

        modelContext.delete(lastRound)
        try? modelContext.save()
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

private struct ScoringToolsBar: View {
    let session: GameSession
    @Binding var selectedTool: ScoringTool?

    var body: some View {
        HStack(spacing: AppTheme.spacingSmall) {
            Label("\(session.gameType.displayName) · Round \(session.currentRoundNumber)", systemImage: session.gameType.icon)
                .font(AppFonts.body)
                .foregroundStyle(session.gameType.color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer()

            ForEach(ScoringTool.allCases) { tool in
                Button {
                    selectedTool = tool
                } label: {
                    Image(systemName: tool.systemImage)
                        .font(.headline)
                        .foregroundStyle(tool.tint)
                        .frame(width: 36, height: 36)
                        .background(.regularMaterial, in: Circle())
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel(tool.title)
            }
        }
        .padding(.horizontal, AppTheme.spacingMedium)
        .padding(.vertical, AppTheme.spacingSmall)
        .background(.ultraThinMaterial)
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
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .monospacedDigit()

                HStack(spacing: AppTheme.spacingSmall) {
                    timerButton("30s", seconds: 30)
                    timerButton("1m", seconds: 60)
                    timerButton("2m", seconds: 120)
                }
            }
        case .dice:
            VStack(spacing: AppTheme.spacingMedium) {
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
            VStack(spacing: AppTheme.spacingMedium) {
                Text(selectedStarter?.name ?? "Pick from \(session.players.count) players")
                    .font(AppFonts.scoreSmall)
                    .multilineTextAlignment(.center)
                AppActionButton(role: .primary(tool.tint)) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
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
                            Spacer()
                            Text(round.entries.map(\.points).reduce(0, +), format: .number)
                                .font(AppFonts.scoreSmall)
                                .monospacedDigit()
                        }
                        .padding(AppTheme.spacingSmall)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
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
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
        .buttonStyle(PressableButtonStyle())
    }
}

private struct ToolArtwork: View {
    let tool: ScoringTool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                .fill(tool.tint.opacity(0.18))
                .overlay(alignment: .bottomTrailing) {
                    Circle()
                        .fill(tool.tint.opacity(0.25))
                        .frame(width: 72, height: 72)
                        .offset(x: 20, y: 24)
                }

            if tool == .starter {
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(index == 1 ? tool.tint : .white.opacity(0.75))
                            .frame(width: index == 1 ? 34 : 24, height: index == 1 ? 34 : 24)
                    }
                }
                .overlay {
                    Image(systemName: "shuffle")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(radius: 4)
                }
            } else {
                Image(systemName: tool.systemImage)
                    .font(.system(size: 48, weight: .semibold, design: .rounded))
                    .foregroundStyle(tool.tint)
                    .frame(width: 72, height: 72)
                    .background(tool.tint.opacity(0.16), in: Circle())
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
        .background(.ultraThinMaterial)
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

            Spacer()

            Text(subtitle)
                .font(AppFonts.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(AppTheme.spacingMedium)
        .appGlass(cornerRadius: AppTheme.cornerRadiusMedium)
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
                    .frame(maxWidth: .infinity, alignment: .leading)

                accessory
            }

            HStack {
                if let title {
                    Text(title)
                        .font(AppFonts.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                ScoreEntryField(
                    value: $value,
                    label: "",
                    range: range,
                    step: step,
                    identifierPrefix: "\(player.name)_"
                )
            }
        }
        .padding(AppTheme.spacingMedium)
        .appGlass(cornerRadius: AppTheme.cornerRadiusMedium, isInteractive: true)
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
                .font(AppFonts.caption)
                .foregroundStyle(.secondary)

            ForEach(session.players, id: \.id) { player in
                HStack(spacing: 6) {
                    Circle()
                        .fill(PlayerColors.color(for: player.colorIndex))
                        .frame(width: 9, height: 9)
                        .accessibilityHidden(true)

                    Text(player.name)
                        .font(AppFonts.caption)
                        .lineLimit(1)

                    Spacer(minLength: AppTheme.spacingSmall)

                    Text("\(round.entry(for: player.id)?.points ?? 0)")
                        .font(AppFonts.caption)
                        .monospacedDigit()
                }
            }
        }
        .padding(AppTheme.spacingSmall)
        .frame(width: 132, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
        .accessibilityLabel("Round \(round.roundNumber)")
    }
}
