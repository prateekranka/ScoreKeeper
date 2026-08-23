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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
            VStack(spacing: AppTheme.spacingMedium) {
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
            .padding(.horizontal, AppTheme.spacingMedium)
            .padding(.top, 8)
            .padding(.bottom, 96)
        }
        .appBackground()
        .navigationTitle("Players")
        .safeAreaInset(edge: .bottom) {
            AppActionButton(role: canStart ? .primary(ClubhouseTheme.blue) : .secondary, action: startGame) {
                Label("Continue", systemImage: "arrow.right")
            }
            .accessibilityIdentifier("start_game_button")
            .disabled(!canStart)
            .padding(.vertical, AppTheme.spacingSmall)
            .padding(.horizontal, AppTheme.spacingSmall)
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
        withAnimation(reduceMotion ? AppMotion.fade : AppMotion.state) {
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
        withAnimation(reduceMotion ? AppMotion.fade : AppMotion.state) {
            for name in names where playerNames.count <= gameType.maxPlayers {
                guard !cleanedNames.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) else { continue }
                if let emptyIndex = playerNames.firstIndex(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                    playerNames[emptyIndex] = name
                } else if playerNames.count < gameType.maxPlayers {
                    playerNames.append(name)
                }
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

private struct SetupPlayerHeader: View {
    let gameType: GameType
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: AppTheme.spacingMedium))
            : AnyLayout(HStackLayout(alignment: .bottom, spacing: AppTheme.spacingMedium))

        layout {
            VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                Text("Add\nPlayers")
                    .font(AppFonts.hero)
                    .foregroundStyle(ClubhouseTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Build tonight's lineup.")
                    .font(AppFonts.body)
                    .foregroundStyle(ClubhouseTheme.inkMuted)

                Label(gameType.displayName, systemImage: gameType.icon)
                    .font(AppFonts.caption.weight(.bold))
                    .foregroundStyle(gameType.color)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !dynamicTypeSize.isAccessibilitySize {
                PipCountGeometricArtwork(scene: .playerSetup)
                    .frame(width: 176, height: 154)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(ClubhouseTheme.paperCard)
        .overlay {
            Rectangle().stroke(ClubhouseTheme.ruleStrong, lineWidth: 1)
        }
    }

    private func removePlayer(at index: Int) {
        if reduceMotion {
            _ = playerNames.remove(at: index)
        } else {
            withAnimation(AppMotion.fade) {
                _ = playerNames.remove(at: index)
            }
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
                .font(AppFonts.headline)
                .foregroundStyle(ClubhouseTheme.ink)
                .textFieldStyle(.plain)
                .focused(focusedIndex, equals: index)
                .autocorrectionDisabled()
                .padding(.horizontal, AppTheme.spacingSmall)
                .padding(.vertical, 12)
                .background(ClubhouseTheme.paperCard)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(ClubhouseTheme.rule).frame(height: 1)
                }
                .accessibilityIdentifier("player_name_field_\(index)")

            if canRemove {
                Button("Remove Player", systemImage: "minus.circle", action: onRemove)
                    .labelStyle(.iconOnly)
                    .font(.title3)
                    .foregroundStyle(ClubhouseTheme.ink)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityIdentifier("remove_player_\(index)_button")
            }
        }
        .frame(minHeight: 58)
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
                Button(action: onAdd) {
                    HStack {
                        Image(systemName: "plus")
                            .font(.headline)
                            .foregroundStyle(ClubhouseTheme.onPrimary)
                            .frame(width: 36, height: 36)
                            .background(ClubhouseTheme.blue, in: Circle())
                        Text("Add Player")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(AppFonts.body.weight(.semibold))
                    .foregroundStyle(ClubhouseTheme.ink)
                    .padding(.horizontal, AppTheme.spacingMedium)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 62)
                    .scorecardSurface(cornerRadius: AppTheme.cornerRadiusSmall, isInteractive: true)
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityIdentifier("add_player_button")
            }

            Button(action: onRoster) {
                HStack {
                    Image(systemName: "person.2.fill")
                        .foregroundStyle(ClubhouseTheme.ink)
                        .frame(width: 36, height: 36)
                        .background(ClubhouseTheme.yellow, in: Circle())
                    Text("From Roster")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(AppFonts.body.weight(.semibold))
                .foregroundStyle(ClubhouseTheme.ink)
                .padding(.horizontal, AppTheme.spacingMedium)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 62)
                .scorecardSurface(cornerRadius: AppTheme.cornerRadiusSmall, isInteractive: true)
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityIdentifier("roster_button")
        }
        .frame(maxWidth: .infinity)
    }
}
