import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(NavigationRouter.self) private var router
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<GameSession> { !$0.isComplete },
           sort: \GameSession.createdAt, order: .reverse)
    private var inProgressGames: [GameSession]
    @Query(filter: #Predicate<GameSession> { $0.isComplete },
           sort: \GameSession.createdAt, order: .reverse)
    private var completedGames: [GameSession]

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacingLarge) {
                headerSection
                newGameButton

                if let activeGame = inProgressGames.first {
                    resumeGameCard(activeGame)
                }

                if !completedGames.isEmpty {
                    recentGamesSection
                }
            }
            .padding(AppTheme.spacingMedium)
        }
        .appBackground()
        .navigationTitle("")
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 4) {
            Text("ScoreKeeper")
                .font(AppFonts.largeTitle)
                .foregroundStyle(
                    LinearGradient(
                        colors: [PlayerColors.palette[0], PlayerColors.palette[3], PlayerColors.palette[1]],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            if inProgressGames.isEmpty && completedGames.isEmpty {
                Text("Ready to play?")
                    .font(AppFonts.body)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding(.top, 40)
    }

    // MARK: - New Game Button

    private var newGameButton: some View {
        Button {
            router.push(.gamePicker)
        } label: {
            HStack(spacing: AppTheme.spacingSmall) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                Text("New Game")
                    .font(AppFonts.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.spacingMedium)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                    .fill(
                        LinearGradient(
                            colors: [PlayerColors.palette[3], PlayerColors.palette[0]],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .shadow(color: PlayerColors.palette[3].opacity(0.3), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .padding(.top, AppTheme.spacingMedium)
    }

    // MARK: - Resume Game

    private func resumeGameCard(_ session: GameSession) -> some View {
        Button {
            router.push(.scoring(session.persistentModelID))
        } label: {
            VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                HStack {
                    Image(systemName: "play.circle.fill")
                        .foregroundStyle(.green)
                    Text("Resume Game")
                        .font(AppFonts.headline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: AppTheme.spacingSmall) {
                    Image(systemName: session.gameType.icon)
                        .foregroundStyle(session.gameType.color)
                    Text(session.gameType.displayName)
                        .font(AppFonts.body)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text("\(session.players.count) players")
                        .font(AppFonts.body)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text("Round \(session.sortedRounds.count)")
                        .font(AppFonts.body)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: AppTheme.spacingSmall) {
                    ForEach(session.players, id: \.id) { player in
                        PlayerBadge(name: player.name, colorIndex: player.colorIndex, size: .small, showName: false)
                    }
                }
            }
            .padding(AppTheme.spacingMedium)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Recent Games

    private var recentGamesSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            HStack {
                Text("Recent Games")
                    .font(AppFonts.title)
                Spacer()
                if completedGames.count > 5 {
                    Button("See All") {
                        router.push(.gameHistory)
                    }
                    .font(AppFonts.body)
                }
            }

            ForEach(completedGames.prefix(5)) { session in
                Button {
                    router.push(.gameDetail(session.persistentModelID))
                } label: {
                    recentGameRow(session)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func recentGameRow(_ session: GameSession) -> some View {
        HStack(spacing: AppTheme.spacingSmall) {
            Image(systemName: session.gameType.icon)
                .font(.title3)
                .foregroundStyle(session.gameType.color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.gameType.displayName)
                    .font(AppFonts.body)

                if let winnerID = session.winnerID,
                   let winner = session.players.first(where: { $0.id == winnerID }) {
                    Text("\(winner.name) won")
                        .font(AppFonts.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(session.players.count) players")
                        .font(AppFonts.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let date = session.completedAt {
                Text(date, style: .date)
                    .font(AppFonts.caption)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(AppTheme.spacingSmall)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))
    }
}
