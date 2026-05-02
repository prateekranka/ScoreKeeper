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
                ContentUnavailableView(
                    "No Games Yet",
                    systemImage: "trophy",
                    description: Text("Completed games will appear here.")
                )
            } else {
                List {
                    ForEach(completedGames) { session in
                        Button {
                            router.push(.gameDetail(session.persistentModelID))
                        } label: {
                            gameRow(session)
                        }
                    }
                    .onDelete(perform: deleteGames)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .accessibilityIdentifier("game_history_list")
            }
        }
        .appBackground()
        .navigationTitle("Game History")
    }

    private func gameRow(_ session: GameSession) -> some View {
        HStack(spacing: AppTheme.spacingSmall) {
            Image(systemName: session.gameType.icon)
                .font(.title3)
                .foregroundStyle(session.gameType.color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.gameType.displayName)
                    .font(AppFonts.body)

                HStack(spacing: 4) {
                    if let resultText = resultText(for: session) {
                        Text(resultText)
                    }
                    Text("·")
                    Text("\(session.players.count) players")
                    Text("·")
                    Text("\(session.rounds.count) rounds")
                }
                .font(AppFonts.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if let date = session.completedAt {
                Text(date, style: .date)
                    .font(AppFonts.caption)
                    .foregroundStyle(.secondary)
            }
        }
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
