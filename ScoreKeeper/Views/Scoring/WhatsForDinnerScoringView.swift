import SwiftUI
import SwiftData

struct WhatsForDinnerScoringView: View {
    @Bindable var session: GameSession
    @Environment(\.modelContext) private var modelContext
    @State private var handValues: [UUID: Int] = [:]
    @State private var callerID: UUID?
    @State private var scoreHapticTrigger = 0
    @State private var saveError: String?
    private let engine = WhatsForDinnerEngine()

    var body: some View {
        ScoringScreenLayout(
            session: session,
            engine: engine,
            actionTitle: "Submit",
            actionSystemImage: "fork.knife",
            action: submitRound
        ) {
            mealRevealSection
            playerHandsSection
        } footer: {
            RoundHistoryStrip(session: session)
        }
        .sensoryFeedback(.impact, trigger: scoreHapticTrigger)
        .alert(
            "Couldn’t save round",
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

    private var mealRevealSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            Text("Meal Reveal")
                .columnHeaderStyle()
            Text("Choose the player who called it")
                .font(AppFonts.caption)
                .foregroundStyle(ClubhouseTheme.inkMuted)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.spacingSmall) {
                    ForEach(session.players, id: \.id) { player in
                        let isCaller = callerID == player.id
                        Button {
                            withAnimation(AppMotion.state) {
                                callerID = player.id
                            }
                        } label: {
                            VStack(spacing: 6) {
                                PlayerShapeIcon(colorIndex: player.colorIndex, size: 28)
                                Text(player.name)
                                    .font(AppFonts.caption.weight(.semibold))
                                    .foregroundStyle(ClubhouseTheme.ink)
                                    .lineLimit(1)

                                if isCaller {
                                    StatusPill(kind: .custom("Caller", ClubhouseTheme.bauhausBlue))
                                        .transition(.scale(scale: 0.96).combined(with: .opacity))
                                }
                            }
                            .padding(AppTheme.spacingSmall)
                            .frame(minWidth: 88)
                            .background(ClubhouseTheme.paperCard, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                                    .strokeBorder(
                                        isCaller ? ClubhouseTheme.bauhausBlue : ClubhouseTheme.panelBorder,
                                        lineWidth: isCaller ? 2 : 1
                                    )
                            }
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
            AppSectionHeader(title: "Card Values", systemImage: "number")

            ForEach(session.players, id: \.id) { player in
                ScoreEntryRow(
                    player: player,
                    value: handValueBinding(for: player),
                    range: 0...9999,
                    title: "Hand value"
                ) {
                    if callerID == player.id {
                        Label("Caller", systemImage: "checkmark.circle.fill")
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
