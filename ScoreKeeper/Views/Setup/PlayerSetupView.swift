import SwiftUI
import SwiftData

struct PlayerSetupView: View {
    let gameType: GameType
    @Environment(NavigationRouter.self) private var router
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Player.name) private var allPlayers: [Player]

    @State private var playerNames: [String] = ["", ""]
    @FocusState private var focusedIndex: Int?

    private var recentNames: [String] {
        Array(Set(allPlayers.map(\.name)).filter { !$0.isEmpty }).sorted().prefix(20).map { $0 }
    }

    private var canStart: Bool {
        playerNames.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count >= 2
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacingLarge) {
                headerSection
                playersSection
                addPlayerButton
                startButton
            }
            .padding(AppTheme.spacingMedium)
        }
        .appBackground()
        .navigationTitle("Players")
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: AppTheme.spacingSmall) {
            Image(systemName: gameType.icon)
                .font(.title2)
                .foregroundStyle(gameType.color)
            Text(gameType.displayName)
                .font(AppFonts.title)
        }
    }

    // MARK: - Players

    private var playersSection: some View {
        VStack(spacing: AppTheme.spacingSmall) {
            ForEach(playerNames.indices, id: \.self) { index in
                playerRow(index: index)
            }
        }
    }

    private func playerRow(index: Int) -> some View {
        HStack(spacing: AppTheme.spacingSmall) {
            PlayerBadge(
                name: playerNames[index].isEmpty ? "\(index + 1)" : playerNames[index],
                colorIndex: index,
                size: .small,
                showName: false
            )

            TextField("Player \(index + 1)", text: $playerNames[index])
                .font(AppFonts.body)
                .textFieldStyle(.plain)
                .focused($focusedIndex, equals: index)
                .autocorrectionDisabled()
                .padding(.horizontal, AppTheme.spacingSmall)
                .padding(.vertical, AppTheme.spacingSmall)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))

            if playerNames.count > 2 {
                Button {
                    withAnimation {
                        playerNames.remove(at: index)
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Add Player

    private var addPlayerButton: some View {
        Group {
            if playerNames.count < gameType.maxPlayers {
                Button {
                    withAnimation {
                        playerNames.append("")
                        focusedIndex = playerNames.count - 1
                    }
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Player")
                    }
                    .font(AppFonts.body)
                    .foregroundStyle(gameType.color)
                }
            }
        }
    }

    // MARK: - Start

    private var startButton: some View {
        Button {
            startGame()
        } label: {
            Text("Start Game")
                .font(AppFonts.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppTheme.spacingMedium)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                        .fill(canStart ? gameType.color : Color.gray)
                )
        }
        .buttonStyle(.plain)
        .disabled(!canStart)
        .padding(.top, AppTheme.spacingMedium)
    }

    private func startGame() {
        let names = playerNames.enumerated().map { index, name in
            let trimmed = name.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? "Player \(index + 1)" : trimmed
        }

        if gameType == .generic {
            router.push(.gameConfig(gameType, names))
        } else {
            let session = createSession(names: names)
            router.push(.scoring(session.persistentModelID))
        }
    }

    private func createSession(names: [String], winCondition: WinCondition? = nil) -> GameSession {
        let session = GameSession(gameType: gameType)
        if let wc = winCondition {
            session.winCondition = wc
        }
        modelContext.insert(session)

        for (index, name) in names.enumerated() {
            let player = Player(name: name, colorIndex: index)
            player.session = session
            session.players.append(player)
        }

        try? modelContext.save()
        return session
    }
}
