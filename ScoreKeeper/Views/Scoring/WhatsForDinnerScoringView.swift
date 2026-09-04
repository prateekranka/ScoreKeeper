import SwiftUI
import SwiftData

struct WhatsForDinnerScoringView: View {
    @Bindable var session: GameSession
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var handValues: [UUID: Int] = [:]
    @State private var callerID: UUID?
    @State private var scoreHapticTrigger = 0
    @State private var saveError: String?
    private let engine = WhatsForDinnerEngine()

    var body: some View {
        ScoringScreenLayout(
            session: session,
            engine: engine,
            actionTitle: "submit",
            actionSystemImage: "fork.knife",
            action: submitRound
        ) {
            RoundBanner(
                icon: GameType.whatsForDinner.icon,
                color: GameType.whatsForDinner.color,
                title: "round \(session.currentRoundNumber)",
                subtitle: "lowest total wins"
            )
            mealRevealSection
            playerHandsSection
        } footer: {
            RoundHistoryStrip(session: session)
        }
        .sensoryFeedback(.impact, trigger: scoreHapticTrigger)
        .alert(
            "couldn’t save round",
            isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )
        ) {
            Button("ok", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "please try again")
        }
    }

    private var mealRevealSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            AppSectionHeader(title: "meal reveal", subtitle: "choose the player who called it", systemImage: "person.crop.circle.badge.checkmark")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.spacingSmall) {
                    ForEach(session.players, id: \.id) { player in
                        Button {
                            withAnimation(reduceMotion ? AppMotion.fade : AppMotion.state) {
                                callerID = player.id
                            }
                        } label: {
                            VStack(spacing: 4) {
                                PlayerBadge(
                                    name: player.name,
                                    colorIndex: player.colorIndex,
                                    size: .small,
                                    showName: true
                                )

                                if callerID == player.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(ClubhouseTheme.felt)
                                        .font(.caption)
                                        .transition(reduceMotion ? .opacity : .scale(scale: 0.96).combined(with: .opacity))
                                }
                            }
                            .padding(AppTheme.spacingSmall)
                            .background(
                                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall)
                                    .fill(callerID == player.id ?
                                          PlayerColors.lightColor(for: player.colorIndex) : .clear)
                            )
                        }
                        .buttonStyle(PressableButtonStyle())
                        .accessibilityIdentifier("meal_reveal_\(player.name)")
                        .accessibilityLabel("\(player.name) called Meal Reveal")
                    }
                }
            }
        }
        .padding(AppTheme.spacingMedium)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge)
    }

    private var playerHandsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            AppSectionHeader(title: "card values", systemImage: "number")

            ForEach(session.players, id: \.id) { player in
                ScoreEntryRow(
                    player: player,
                    value: handValueBinding(for: player),
                    range: 0...9999,
                    title: "hand value"
                ) {
                    if callerID == player.id {
                        Label("caller", systemImage: "checkmark.circle.fill")
                            .font(AppFonts.caption)
                            .foregroundStyle(ClubhouseTheme.felt)
                    } else {
                        EmptyView()
                    }
                }
            }
        }
    }

    private func handValueBinding(for player: Player) -> Binding<Int> {
        Binding(
            get: { handValues[player.id] ?? 0 },
            set: { handValues[player.id] = $0 }
        )
    }

    private func submitRound() {
        let round = Round(roundNumber: session.currentRoundNumber)
        round.session = session

        for player in session.players {
            let points = handValues[player.id] ?? 0
            let entry = ScoreEntry(playerID: player.id, points: points)
            entry.round = round
            round.entries.append(entry)
        }

        session.rounds.append(round)
        do {
            try modelContext.save()
        } catch {
            let message = error.localizedDescription
            modelContext.rollback()
            saveError = message
            return
        }

        handValues = [:]
        callerID = nil

        scoreHapticTrigger += 1
    }
}
