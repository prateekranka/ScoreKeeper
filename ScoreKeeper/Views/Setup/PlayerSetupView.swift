import SwiftUI
import SwiftData

struct PlayerSetupView: View {
    let gameType: GameType
    @Environment(NavigationRouter.self) private var router
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Player.name) private var allPlayers: [Player]
    @State private var playerNames: [String] = ["", ""]
    @FocusState private var focusedIndex: Int?
    @State private var showRoster = false

    private var recentNames: [String] {
        Array(Set(allPlayers.map(\.name)).filter { !$0.isEmpty }).sorted().prefix(20).map { $0 }
    }

    private var canStart: Bool {
        validationMessage == nil
    }

    private var cleanedNames: [String] {
        playerNames.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    private var playableNames: [String] {
        cleanedNames.enumerated().map { index, name in
            name.isEmpty ? "Player \(index + 1)" : name
        }
    }

    private var validationMessage: String? {
        let filledNames = cleanedNames.filter { !$0.isEmpty }
        if filledNames.count < gameType.minPlayers {
            return "Add at least \(gameType.minPlayers) players."
        }
        if playerNames.count > gameType.maxPlayers {
            return "This game supports up to \(gameType.maxPlayers) players."
        }
        let lowercaseNames = filledNames.map { $0.lowercased() }
        if Set(lowercaseNames).count != lowercaseNames.count {
            return "Player names must be unique."
        }
        return nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacingLarge) {
                SetupPlayerHeader(gameType: gameType)

                if !recentNames.isEmpty {
                    SavedPlayersBar(
                        names: recentNames,
                        cleanedNames: cleanedNames,
                        onTap: addRosterNames
                    )
                }

                PlayerNameFields(
                    playerNames: $playerNames,
                    focusedIndex: $focusedIndex,
                    gameType: gameType
                )

                AddPlayerControls(
                    gameType: gameType,
                    playerCount: playerNames.count,
                    onAdd: addPlayer,
                    onRoster: { showRoster = true }
                )

                if let validationMessage {
                    Text(validationMessage)
                        .font(AppFonts.caption)
                        .foregroundStyle(ClubhouseTheme.lacquer)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(AppTheme.spacingMedium)
        }
        .appBackground()
        .navigationTitle("Players")
        .safeAreaInset(edge: .bottom) {
            AppActionButton(role: canStart ? .primary(gameType.color) : .secondary, action: startGame) {
                Text("Start Game")
            }
            .accessibilityIdentifier("start_game_button")
            .disabled(!canStart)
            .padding(.horizontal, AppTheme.spacingMedium)
            .padding(.vertical, AppTheme.spacingSmall)
            .background(.ultraThinMaterial)
        }
        .sheet(isPresented: $showRoster) {
            PlayerRosterSheet { names in addRosterNames(names) }
        }
    }

    private func addPlayer() {
        withAnimation {
            playerNames.append("")
            focusedIndex = playerNames.count - 1
        }
    }

    private func startGame() {
        let names = playableNames
        if gameType == .generic || gameType == .phase10 {
            router.push(.gameConfig(gameType, names))
        } else {
            let session = createSession(names: names)
            router.push(.scoring(session.persistentModelID))
        }
    }

    private func addRosterNames(_ names: [String]) {
        for name in names where playerNames.count <= gameType.maxPlayers {
            guard !cleanedNames.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) else { continue }
            if let emptyIndex = playerNames.firstIndex(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                playerNames[emptyIndex] = name
            } else if playerNames.count < gameType.maxPlayers {
                playerNames.append(name)
            }
        }
    }

    private func createSession(names: [String], winCondition: WinCondition? = nil) -> GameSession {
        let session = GameSession(gameType: gameType)
        if let wc = winCondition { session.winCondition = wc }
        modelContext.insert(session)

        for (index, name) in names.enumerated() {
            let player = Player(name: name, colorIndex: index)
            player.session = session
            session.players.append(player)
        }

        try? modelContext.save()
        savePlayersToRoster(names: names)
        return session
    }

    private func savePlayersToRoster(names: [String]) {
        for name in names {
            let existing = try? modelContext.fetch(
                FetchDescriptor<SavedPlayer>(predicate: #Predicate { $0.name == name })
            ).first

            if let existing {
                existing.gamesPlayed += 1
                existing.lastUsed = .now
            } else {
                let saved = SavedPlayer(name: name, colorIndex: Int.random(in: 0..<PlayerColors.palette.count))
                saved.gamesPlayed = 1
                modelContext.insert(saved)
            }
        }
    }
}

// MARK: - Subviews

private struct SetupPlayerHeader: View {
    let gameType: GameType

    var body: some View {
        VStack(spacing: AppTheme.spacingMedium) {
            VStack(spacing: AppTheme.spacingSmall) {
                Image(systemName: gameType.icon)
                    .font(.title2)
                    .foregroundStyle(gameType.color)
                Text(gameType.displayName)
                    .font(AppFonts.title)
                    .foregroundStyle(ClubhouseTheme.ink)
                Text("\(gameType.minPlayers)-\(gameType.maxPlayers) players")
                    .font(AppFonts.caption)
                    .foregroundStyle(ClubhouseTheme.inkMuted)
            }

            HStack(spacing: AppTheme.spacingSmall) {
                Label(gameType.defaultWinCondition == .highestScore ? "Highest wins" : "Lowest wins", systemImage: "trophy.fill")
                Label("Saved roster", systemImage: "person.2.fill")
                Label("Fast start", systemImage: "bolt.fill")
            }
            .font(AppFonts.caption)
            .foregroundStyle(gameType.color)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(maxWidth: .infinity)
        }
        .padding(AppTheme.spacingMedium)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge)
    }
}

private struct SavedPlayersBar: View {
    let names: [String]
    let cleanedNames: [String]
    let onTap: ([String]) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            AppSectionHeader(
                title: "Saved Players",
                subtitle: "Tap names to fill the table faster.",
                systemImage: "person.crop.circle.badge.plus"
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.spacingSmall) {
                    ForEach(names, id: \.self) { name in
                        let alreadyAdded = cleanedNames.contains { $0.caseInsensitiveCompare(name) == .orderedSame }
                        Button {
                            onTap([name])
                        } label: {
                            PaperChip(isSelected: alreadyAdded) {
                                Label(name, systemImage: alreadyAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                            }
                        }
                        .buttonStyle(PressableButtonStyle())
                        .disabled(alreadyAdded)
                    }
                }
            }
        }
    }
}

private struct PlayerNameFields: View {
    @Binding var playerNames: [String]
    var focusedIndex: FocusState<Int?>.Binding
    let gameType: GameType

    var body: some View {
        VStack(spacing: AppTheme.spacingSmall) {
            ForEach(playerNames.indices, id: \.self) { index in
                PlayerNameRow(
                    name: $playerNames[index],
                    index: index,
                    canRemove: playerNames.count > 2,
                    focusedIndex: focusedIndex,
                    onRemove: { removePlayer(at: index) }
                )
            }
        }
    }

    private func removePlayer(at index: Int) {
        withAnimation {
            _ = playerNames.remove(at: index)
        }
    }
}

private struct PlayerNameRow: View {
    @Binding var name: String
    let index: Int
    let canRemove: Bool
    var focusedIndex: FocusState<Int?>.Binding
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: AppTheme.spacingSmall) {
            PlayerBadge(
                name: name.isEmpty ? "\(index + 1)" : name,
                colorIndex: index,
                size: .small,
                showName: false
            )

            TextField("Player \(index + 1)", text: $name)
                .font(AppFonts.body)
                .foregroundStyle(ClubhouseTheme.ink)
                .textFieldStyle(.plain)
                .focused(focusedIndex, equals: index)
                .autocorrectionDisabled()
                .padding(.horizontal, AppTheme.spacingSmall)
                .padding(.vertical, AppTheme.spacingSmall)
                .background(ClubhouseTheme.paperCard)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(ClubhouseTheme.rule).frame(height: 1)
                }
                .accessibilityIdentifier("player_name_field_\(index)")

            if canRemove {
                Button("Remove Player", systemImage: "xmark.circle.fill", action: onRemove)
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityIdentifier("remove_player_\(index)_button")
            }
        }
    }
}

private struct AddPlayerControls: View {
    let gameType: GameType
    let playerCount: Int
    let onAdd: () -> Void
    let onRoster: () -> Void

    var body: some View {
        Group {
            if playerCount < gameType.maxPlayers {
                Button(action: onAdd) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Player")
                    }
                    .font(AppFonts.body)
                    .foregroundStyle(ClubhouseTheme.felt)
                }
                .accessibilityIdentifier("add_player_button")
            }

            Button(action: onRoster) {
                Label("From Roster", systemImage: "person.2.fill")
                    .font(AppFonts.body)
                    .foregroundStyle(ClubhouseTheme.felt)
            }
            .accessibilityIdentifier("roster_button")
        }
        .frame(maxWidth: .infinity)
    }
}
