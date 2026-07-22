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
    @State private var sectionsVisible = false
    #if DEBUG
    @ObservedObject private var tuning = PipTuning.shared
    #endif

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
                .staggeredEntrance(visible: sectionsVisible, index: 0)

                if !recentNames.isEmpty {
                    SavedPlayersBar(
                        names: recentNames,
                        cleanedNames: cleanedNames,
                        onTap: addRosterNames
                    )
                    .staggeredEntrance(visible: sectionsVisible, index: 1)
                }

                PlayerNameFields(
                    playerNames: $playerNames,
                    focusedIndex: $focusedIndex,
                    gameType: gameType
                )
                .staggeredEntrance(visible: sectionsVisible, index: recentNames.isEmpty ? 1 : 2)

                AddPlayerControls(
                    gameType: gameType,
                    playerCount: playerNames.count,
                    onAdd: addPlayer,
                    onRoster: { showRoster = true }
                )
                .staggeredEntrance(visible: sectionsVisible, index: recentNames.isEmpty ? 2 : 3)

                if let validationMessage {
                    Text(validationMessage)
                        .font(AppFonts.caption)
                        .foregroundStyle(ClubhouseTheme.lacquer)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("player_setup_validation")
                }
            }
            .padding(AppTheme.spacingMedium)
            .padding(.bottom, 24)
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
            .background(ClubhouseTheme.paper.opacity(0.94))
            #if DEBUG
            .padding(.bottom, focusedIndex != nil ? CGFloat(tuning.setupCTAKeyboardGap) : AppTheme.spacingSmall)
            #else
            .padding(.bottom, AppTheme.spacingSmall)
            #endif
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
        .onAppear { sectionsVisible = true }
    }

    private func addPlayer() {
        withAnimation(AppMotion.state) {
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
                let saved = SavedPlayer(name: name, colorIndex: names.firstIndex(of: name) ?? 0)
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
            Text("Saved")
                .columnHeaderStyle()
            Text("Tap a name to drop them into the lineup.")
                .font(AppFonts.caption)
                .foregroundStyle(ClubhouseTheme.inkMuted)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.spacingSmall) {
                    ForEach(names, id: \.self) { name in
                        let alreadyAdded = cleanedNames.contains { $0.caseInsensitiveCompare(name) == .orderedSame }
                        Button {
                            onTap([name])
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: alreadyAdded ? "checkmark" : "plus")
                                    .font(.caption.weight(.bold))
                                Text(name)
                                    .font(AppFonts.caption.weight(.semibold))
                            }
                            .foregroundStyle(alreadyAdded ? ClubhouseTheme.onPrimary : ClubhouseTheme.ink)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 36)
                            .background(
                                alreadyAdded ? ClubhouseTheme.bauhausBlue : ClubhouseTheme.paperCard,
                                in: Capsule()
                            )
                            .overlay {
                                Capsule()
                                    .strokeBorder(
                                        alreadyAdded ? ClubhouseTheme.bauhausBlue : ClubhouseTheme.panelBorder,
                                        lineWidth: 1
                                    )
                            }
                        }
                        .buttonStyle(PressableButtonStyle())
                        .disabled(alreadyAdded)
                        .accessibilityLabel(alreadyAdded ? "\(name), already added" : "Add \(name)")
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
        VStack(spacing: 0) {
            ForEach(playerNames.indices, id: \.self) { index in
                PlayerNameRow(
                    name: $playerNames[index],
                    index: index,
                    canRemove: playerNames.count > 2,
                    focusedIndex: focusedIndex,
                    onRemove: { removePlayer(at: index) }
                )

                if index < playerNames.count - 1 {
                    Rectangle()
                        .fill(ClubhouseTheme.rule)
                        .frame(height: 1)
                        .padding(.leading, 52)
                }
            }
        }
        .padding(.vertical, AppTheme.spacingSmall)
        .padding(.horizontal, AppTheme.spacingMedium)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge)
    }

    private func removePlayer(at index: Int) {
        withAnimation(AppMotion.state) {
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
            PlayerShapeIcon(colorIndex: index, size: 32)

            TextField("Player \(index + 1)", text: $name)
                .font(AppFonts.body.weight(.semibold))
                .foregroundStyle(ClubhouseTheme.ink)
                .textFieldStyle(.plain)
                .focused(focusedIndex, equals: index)
                .autocorrectionDisabled()
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(ClubhouseTheme.paperSunken, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                        .strokeBorder(
                            isFocused ? ClubhouseTheme.bauhausBlue : ClubhouseTheme.panelBorder,
                            lineWidth: isFocused ? 2 : 1
                        )
                }
                .animation(AppMotion.state, value: isFocused)
                .accessibilityIdentifier("player_name_field_\(index)")

            if canRemove {
                Button(action: onRemove) {
                    Image(systemName: "minus")
                        .font(.body.weight(.bold))
                        .foregroundStyle(ClubhouseTheme.bauhausRed)
                        .frame(width: 36, height: 36)
                        .overlay {
                            Circle()
                                .strokeBorder(ClubhouseTheme.bauhausRed.opacity(0.45), lineWidth: 1.5)
                        }
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel("Remove Player")
                .accessibilityIdentifier("remove_player_\(index)_button")
            }
        }
        .padding(.vertical, 8)
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
                    subtitle: "Open another seat at the table.",
                    iconFill: ClubhouseTheme.bauhausBlue,
                    iconSymbol: "plus",
                    action: onAdd
                )
                .accessibilityIdentifier("add_player_button")
            }

            lineupActionButton(
                title: "From Roster",
                subtitle: "Pull in a saved crew.",
                iconFill: ClubhouseTheme.bauhausYellow,
                iconSymbol: "person.2.fill",
                action: onRoster
            )
            .accessibilityIdentifier("roster_button")
        }
    }

    private func lineupActionButton(
        title: String,
        subtitle: String,
        iconFill: Color,
        iconSymbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: AppTheme.spacingSmall) {
                ZStack {
                    Circle()
                        .fill(iconFill)
                        .frame(width: 40, height: 40)
                    Image(systemName: iconSymbol)
                        .font(.body.weight(.bold))
                        .foregroundStyle(iconFill == ClubhouseTheme.bauhausYellow ? ClubhouseTheme.ink : ClubhouseTheme.onPrimary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppFonts.body.weight(.semibold))
                        .foregroundStyle(ClubhouseTheme.ink)
                    Text(subtitle)
                        .font(AppFonts.caption)
                        .foregroundStyle(ClubhouseTheme.inkMuted)
                }

                Spacer(minLength: 0)

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
