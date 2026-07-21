import SwiftUI
import SwiftData

struct GameHistoryListView: View {
    @Environment(NavigationRouter.self) private var router
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<GameSession> { $0.isComplete },
           sort: \GameSession.createdAt, order: .reverse)
    private var completedGames: [GameSession]

    var body: some View {
        Group {
            if completedGames.isEmpty {
                ScrollView {
                    BauhausEmptyState(
                        title: "No Games Yet",
                        message: "Completed games will appear here once you finish a scoreboard.",
                        systemImage: "trophy.fill",
                        heroStyle: .gameOver,
                        actionTitle: "Start a Game",
                        action: { router.push(.gamePicker) }
                    )
                    .padding(AppTheme.spacingMedium)
                }
            } else {
                List {
                    Section {
                        ForEach(completedGames) { session in
                            Button {
                                router.push(.gameDetail(session.persistentModelID))
                            } label: {
                                gameRow(session)
                            }
                            .buttonStyle(PressableButtonStyle())
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowBackground(Color.clear)
                        }
                        .onDelete(perform: deleteGames)
                    } header: {
                        Text("Archive")
                            .columnHeaderStyle()
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .accessibilityIdentifier("game_history_list")
            }
        }
        .appBackground()
        .navigationTitle("Game History")
    }

    private func gameRow(_ session: GameSession) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.gameType.displayName)
                        .font(AppFonts.headline)
                        .foregroundStyle(ClubhouseTheme.ink)

                    if let date = session.completedAt {
                        Text(date, style: .date)
                            .font(AppFonts.caption)
                            .foregroundStyle(ClubhouseTheme.inkMuted)
                    }
                }
                Spacer()
                StatusPill(kind: .completed)
            }

            HStack(spacing: 4) {
                VStack(alignment: .leading, spacing: 2) {
                    if let resultText = resultText(for: session) {
                        Text(resultText)
                            .foregroundStyle(ClubhouseTheme.bauhausGreen)
                    }
                    Text("\(session.players.count.quantityText("player")) / \(session.rounds.count.quantityText("round"))")
                        .foregroundStyle(ClubhouseTheme.inkMuted)
                }
                .font(AppFonts.caption)

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ClubhouseTheme.inkMuted)
            }
        }
        .padding(AppTheme.spacingSmall)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusSmall, isInteractive: true)
        .accessibilityElement(children: .combine)
    }

    private func deleteGames(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(completedGames[index])
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
