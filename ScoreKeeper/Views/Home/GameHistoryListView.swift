import SwiftData
import SwiftUI

struct GameHistoryListView: View {
    @Environment(NavigationRouter.self) private var router
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Query(sort: \GameSession.createdAt, order: .reverse)
    private var sessions: [GameSession]

    @State private var contentVisible = false
    @State private var sessionPendingDeletion: GameSession?

    private var completedSessions: [GameSession] {
        sessions.filter { $0.completedAt != nil }
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.spacingLarge) {
                    hero
                        .historyEntrance(contentVisible, index: 0, reduceMotion: reduceMotion)

                    if completedSessions.isEmpty {
                        emptyState
                            .historyEntrance(contentVisible, index: 1, reduceMotion: reduceMotion)
                    } else {
                        gameGrid(width: proxy.size.width)
                            .historyEntrance(contentVisible, index: 1, reduceMotion: reduceMotion)
                    }
                }
                .padding(.horizontal, proxy.size.width >= 820 ? AppTheme.spacingXLarge : AppTheme.spacingMedium)
                .padding(.vertical, AppTheme.spacingMedium)
                .frame(maxWidth: 1180)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .scrollIndicators(.hidden)
        }
        .appBackground()
        .navigationTitle("Game History")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { contentVisible = true }
        .confirmationDialog(
            "Delete this game?",
            isPresented: Binding(
                get: { sessionPendingDeletion != nil },
                set: { if !$0 { sessionPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Game", role: .destructive) {
                deletePendingSession()
            }
            Button("Cancel", role: .cancel) {
                sessionPendingDeletion = nil
            }
        } message: {
            Text("This removes its scores and stats from PipCount.")
        }
    }

    private var hero: some View {
        HStack(alignment: .top, spacing: AppTheme.spacingLarge) {
            VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                Text("Every night\nbecomes history.")
                    .font(AppFonts.display)
                    .foregroundStyle(ClubhouseTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Final scores, rematches, and the story of your table — saved automatically.")
                    .font(AppFonts.body)
                    .foregroundStyle(ClubhouseTheme.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)

                Rectangle()
                    .fill(ClubhouseTheme.green)
                    .frame(width: 92, height: 5)
            }

            Spacer(minLength: AppTheme.spacingSmall)

            PipCountGeometricArtwork(scene: .onboardingHistory)
                .frame(minWidth: 160, idealWidth: 260, maxWidth: 340)
                .frame(height: 250)
        }
    }

    private var emptyState: some View {
        VStack(spacing: AppTheme.spacingLarge) {
            PipCountGeometricArtwork(scene: .onboardingHistory)
                .frame(maxWidth: 390)
                .frame(height: 300)

            VStack(spacing: AppTheme.spacingSmall) {
                Text("No finished games yet")
                    .font(AppFonts.hero)
                    .foregroundStyle(ClubhouseTheme.ink)

                Text("Complete a game and its recap will appear here.")
                    .font(AppFonts.body)
                    .foregroundStyle(ClubhouseTheme.inkMuted)
                    .multilineTextAlignment(.center)
            }

            AppActionButton(role: .primary(ClubhouseTheme.blue)) {
                router.push(.gamePicker)
            } label: {
                Label("Start a New Game", systemImage: "plus")
            }
            .frame(maxWidth: 420)
        }
        .padding(AppTheme.spacingXLarge)
        .frame(maxWidth: .infinity)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge)
    }

    private func gameGrid(width: CGFloat) -> some View {
        let columnCount = width >= 1040 ? 3 : (width >= 700 ? 2 : 1)
        let columns = Array(repeating: GridItem(.flexible(), spacing: AppTheme.spacingMedium), count: columnCount)

        return LazyVGrid(columns: columns, spacing: AppTheme.spacingMedium) {
            ForEach(Array(completedSessions.enumerated()), id: \.element.id) { index, session in
                gameCard(session)
                    .accessibilityIdentifier("history_card_\(index)")
            }
        }
    }

    private func gameCard(_ session: GameSession) -> some View {
        Button {
            router.push(.gameDetail(session.persistentModelID))
        } label: {
            VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
                HStack(alignment: .top, spacing: AppTheme.spacingSmall) {
                    GameTypeArtwork(gameType: session.gameType)
                        .frame(width: 72, height: 72)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.gameType.displayName)
                            .font(AppFonts.title)
                            .foregroundStyle(ClubhouseTheme.ink)
                            .lineLimit(2)

                        Text(completedDate(session))
                            .font(AppFonts.caption)
                            .foregroundStyle(ClubhouseTheme.inkMuted)
                    }

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(ClubhouseTheme.inkMuted)
                        .padding(.top, 4)
                }

                Rectangle()
                    .fill(ClubhouseTheme.rule)
                    .frame(height: 1)

                HStack(alignment: .bottom, spacing: AppTheme.spacingSmall) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(resultTitle(session))
                            .font(AppFonts.headline)
                            .foregroundStyle(ClubhouseTheme.ink)
                            .lineLimit(2)

                        Text("\(session.sortedRounds.count) \(session.sortedRounds.count == 1 ? "round" : "rounds") • \(session.players.count) players")
                            .font(AppFonts.caption)
                            .foregroundStyle(ClubhouseTheme.inkMuted)
                    }

                    Spacer()

                    let leader = sortedPlayers(session).first
                    Text(leader.map { "\($0.totalScore(in: session))" } ?? "—")
                        .font(AppFonts.scoreMedium)
                        .foregroundStyle(ClubhouseTheme.blue)
                        .monospacedDigit()
                }

                HStack(spacing: 6) {
                    ForEach(session.players.prefix(8)) { player in
                        BauhausPlayerShape(colorIndex: player.colorIndex, size: 18)
                    }

                    Spacer()

                    Text("GAME OVER")
                        .font(AppFonts.columnHeader)
                        .tracking(1.1)
                        .foregroundStyle(ClubhouseTheme.red)
                }
            }
            .padding(AppTheme.spacingMedium)
            .frame(maxWidth: .infinity, minHeight: 230, alignment: .topLeading)
            .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge, isInteractive: true)
        }
        .buttonStyle(PressableButtonStyle())
        .contextMenu {
            Button(role: .destructive) {
                sessionPendingDeletion = session
            } label: {
                Label("Delete Game", systemImage: "trash")
            }
        }
        .accessibilityLabel("\(session.gameType.displayName), \(resultTitle(session)), \(completedDate(session))")
    }

    private func resultTitle(_ session: GameSession) -> String {
        let names = winners(session).map(\.name)
        if names.count == 1 { return "\(names[0]) won" }
        if names.count > 1 { return "Tie: \(names.joined(separator: ", "))" }
        return "No winner"
    }

    private func winners(_ session: GameSession) -> [Player] {
        let ids = Set(GameEngineFactory.engine(for: session.gameType).winners(session: session))
        return session.players.filter { ids.contains($0.id) }
    }

    private func sortedPlayers(_ session: GameSession) -> [Player] {
        session.players.sorted { lhs, rhs in
            let left = lhs.totalScore(in: session)
            let right = rhs.totalScore(in: session)
            if left == right {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return session.winCondition == .highestScore ? left > right : left < right
        }
    }

    private func completedDate(_ session: GameSession) -> String {
        (session.completedAt ?? session.createdAt).formatted(.dateTime.day().month(.abbreviated).year())
    }

    private func deletePendingSession() {
        guard let sessionPendingDeletion else { return }
        modelContext.delete(sessionPendingDeletion)
        try? modelContext.save()
        self.sessionPendingDeletion = nil
    }
}

private struct GameHistoryEntranceModifier: ViewModifier {
    let visible: Bool
    let index: Int
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible || reduceMotion ? 0 : 16)
            .animation(
                reduceMotion ? AppMotion.fade : AppMotion.artEntrance.delay(Double(index) * 0.055),
                value: visible
            )
    }
}

private extension View {
    func historyEntrance(_ visible: Bool, index: Int, reduceMotion: Bool) -> some View {
        modifier(GameHistoryEntranceModifier(visible: visible, index: index, reduceMotion: reduceMotion))
    }
}
