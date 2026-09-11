import SwiftUI
import SwiftData

struct WhatsForDinnerScoringView: View {
    @Bindable var session: GameSession
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var callerID: UUID?
    @State private var scoreHapticTrigger = 0
    @State private var showDeck = false
    private let engine = WhatsForDinnerEngine()

    var body: some View {
        ScoringScreenLayout(
            session: session,
            engine: engine,
            actionTitle: "score round",
            actionSystemImage: "pencil.line",
            action: { showDeck = true }
        ) {
            RoundBanner(
                icon: GameType.whatsForDinner.icon,
                color: GameType.whatsForDinner.color,
                title: "round \(session.currentRoundNumber)",
                subtitle: "lowest total wins"
            )
            mealRevealSection
        } footer: {
            RoundHistoryStrip(session: session)
        }
        .fullScreenCover(isPresented: $showDeck) {
            RoundEntryDeckView(
                session: session,
                onSubmit: { roundScores in
                    submitRound(using: roundScores)
                },
                onCancel: { showDeck = false }
            )
        }
        .sensoryFeedback(.impact, trigger: scoreHapticTrigger)
    }

    private var mealRevealSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            AppSectionHeader(title: "meal reveal", subtitle: "choose the player who called it, then write every hand with the score deck", systemImage: "person.crop.circle.badge.checkmark")

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
                                    Label("caller", systemImage: "checkmark.circle.fill")
                                        .font(AppFonts.caption)
                                        .foregroundStyle(ClubhouseTheme.felt)
                                        .transition(reduceMotion ? .opacity : .scale(scale: 0.96).combined(with: .opacity))
                                } else {
                                    Text("tap to pick")
                                        .font(AppFonts.caption)
                                        .foregroundStyle(ClubhouseTheme.inkMuted)
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

    /// Returns nil after a successful save (the deck then dismisses); returns
    /// a user-facing message when the round cannot be saved, so the deck can
    /// stay open with the confirmed scores intact (PC17-003).
    private func submitRound(using roundScores: [UUID: Int]) -> String? {
        // The save boundary rejects incomplete dictionaries; it never
        // substitutes zero for a player who did not confirm a score.
        guard session.players.allSatisfy({ roundScores[$0.id] != nil }) else {
            return "every player needs a confirmed score before this round can save"
        }

        let round = Round(roundNumber: session.currentRoundNumber)
        round.session = session

        for player in session.players {
            guard let points = roundScores[player.id] else {
                return "every player needs a confirmed score before this round can save"
            }
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
            return message
        }

        showDeck = false
        callerID = nil
        scoreHapticTrigger += 1
        return nil
    }
}
