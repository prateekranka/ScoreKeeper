import SwiftUI
import SwiftData

struct PlayerSetupView: View {
    let gameType: GameType
    @Environment(NavigationRouter.self) private var router
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreManager.self) private var storeManager
    @Query(sort: \Player.name) private var allPlayers: [Player]
    @State private var playerNames: [String] = ["", ""]
    @FocusState private var focusedIndex: Int?
    @State private var showRoster = false
    @State private var showPaywall = false
    @State private var saveError: String?

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
                BauhausScreenHeader(
                    title: "Add Players",
                    subtitle: "Build tonight's lineup.",
                    heroStyle: .addPlayers
                )

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
            BauhausPrimaryButton(
                title: "Start Game",
                systemImage: "play.fill",
                fill: canStart ? gameType.color : ClubhouseTheme.inkMuted,
                action: startGame
            )
            .accessibilityIdentifier("start_game_button")
            .disabled(!canStart)
            .opacity(canStart ? 1 : 0.48)
            .padding(.vertical, AppTheme.spacingSmall)
            .padding(.horizontal, AppTheme.spacingMedium)
            .appGlass(cornerRadius: AppTheme.cornerRadiusLarge, isInteractive: true)
            .padding(.horizontal, AppTheme.spacingMedium)
            .padding(.bottom, AppTheme.spacingSmall)
        }
        .sheet(isPresented: $showRoster) {
            PlayerRosterSheet { names in addRosterNames(names) }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(onUnlocked: startGame)
                .presentationDetents([.large])
        }
        .alert(
            "Couldn’t save game",
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
            guard storeManager.canStartNewGame else {
                showPaywall = true
                return
            }

            guard let session = createSession(names: names) else { return }
            storeManager.recordGameStarted()
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

    private func createSession(names: [String], winCondition: WinCondition? = nil) -> GameSession? {
        let session = GameSession(gameType: gameType)
        if let wc = winCondition { session.winCondition = wc }
        modelContext.insert(session)

        for (index, name) in names.enumerated() {
            let player = Player(name: name, colorIndex: index)
            player.session = session
            session.players.append(player)
        }

        do {
            try savePlayersToRoster(names: names)
            try modelContext.save()
            return session
        } catch {
            let message = error.localizedDescription
            modelContext.rollback()
            saveError = message
            return nil
        }
    }

    private func savePlayersToRoster(names: [String]) throws {
        for name in names {
            let existing = try modelContext.fetch(
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
        .padding(AppTheme.spacingMedium)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge)
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
        .padding(AppTheme.spacingMedium)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge)
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

    private var isFocused: Bool {
        focusedIndex.wrappedValue == index
    }

    var body: some View {
        HStack(spacing: AppTheme.spacingSmall) {
            Image(systemName: "line.3.horizontal")
                .font(.caption.weight(.bold))
                .foregroundStyle(ClubhouseTheme.inkMuted)
                .frame(width: 20)
                .accessibilityHidden(true)

            PlayerShapeIcon(colorIndex: index, size: 32)

            TextField("Player \(index + 1)", text: $name)
                .font(AppFonts.body)
                .foregroundStyle(ClubhouseTheme.ink)
                .textFieldStyle(.plain)
                .focused(focusedIndex, equals: index)
                .autocorrectionDisabled()
                .padding(.horizontal, AppTheme.spacingSmall)
                .padding(.vertical, AppTheme.spacingSmall)
                .background(ClubhouseTheme.paperSunken, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                        .strokeBorder(
                            isFocused ? ClubhouseTheme.bauhausBlue : ClubhouseTheme.rule,
                            lineWidth: isFocused ? 2 : 1
                        )
                }
                .accessibilityIdentifier("player_name_field_\(index)")

            if canRemove {
                Button("Remove Player", systemImage: "xmark.circle.fill", action: onRemove)
                    .labelStyle(.iconOnly)
                    .foregroundStyle(ClubhouseTheme.inkMuted)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityIdentifier("remove_player_\(index)_button")
            }
        }
        .padding(.vertical, 4)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(ClubhouseTheme.rule)
                .frame(height: 1)
        }
    }
}

private struct AddPlayerControls: View {
    let gameType: GameType
    let playerCount: Int
    let onAdd: () -> Void
    let onRoster: () -> Void

    var body: some View {
        VStack(spacing: AppTheme.spacingSmall) {
            if playerCount < gameType.maxPlayers {
                lineupActionButton(
                    title: "Add Player",
                    iconFill: ClubhouseTheme.bauhausBlue,
                    iconSymbol: "plus",
                    action: onAdd
                )
                .accessibilityIdentifier("add_player_button")
            }

            lineupActionButton(
                title: "From Roster",
                iconFill: ClubhouseTheme.bauhausYellow,
                iconSymbol: "person.2.fill",
                action: onRoster
            )
            .accessibilityIdentifier("roster_button")
        }
    }

    private func lineupActionButton(
        title: String,
        iconFill: Color,
        iconSymbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: AppTheme.spacingSmall) {
                ZStack {
                    Circle()
                        .fill(iconFill)
                        .frame(width: 36, height: 36)
                    Image(systemName: iconSymbol)
                        .font(.body.weight(.bold))
                        .foregroundStyle(iconFill == ClubhouseTheme.bauhausYellow ? ClubhouseTheme.ink : .white)
                }

                Text(title)
                    .font(AppFonts.body.weight(.semibold))
                    .foregroundStyle(ClubhouseTheme.ink)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ClubhouseTheme.inkMuted)
            }
            .padding(AppTheme.spacingMedium)
            .scorecardSurface(cornerRadius: AppTheme.cornerRadiusMedium, isInteractive: true)
        }
        .buttonStyle(PressableButtonStyle())
    }
}
