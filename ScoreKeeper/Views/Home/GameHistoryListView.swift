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
                    Section {
                        ForEach(completedGames) { session in
                            Button {
                                router.push(.gameDetail(session.persistentModelID))
                            } label: {
                                gameRow(session)
                            }
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
                            .columnHeaderStyle()
                    }
                }
                Spacer()
                StampBadge(text: "Final")
            }

            HStack(spacing: 4) {
                VStack(alignment: .leading, spacing: 2) {
                    if let resultText = resultText(for: session) {
                        Text(resultText)
                            .foregroundStyle(ClubhouseTheme.brass)
                    }
                    Text("\(session.players.count.quantityText("player")) / \(session.rounds.count.quantityText("round"))")
                        .foregroundStyle(ClubhouseTheme.inkMuted)
                }
                .font(AppFonts.caption)

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
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
