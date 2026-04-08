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
            }
        }
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
                    if let winnerID = session.winnerID,
                       let winner = session.players.first(where: { $0.id == winnerID }) {
                        Text("\(winner.name) won")
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
    }

    private func deleteGames(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(completedGames[index])
        }
    }
}
