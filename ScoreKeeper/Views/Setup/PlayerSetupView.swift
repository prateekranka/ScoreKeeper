import SwiftUI
import SwiftData

struct PlayerSetupView: View {
    let gameType: GameType

    @Environment(NavigationRouter.self) private var router
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreManager.self) private var storeManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Query(sort: \Player.name) private var allPlayers: [Player]
    @State private var playerNames: [String] = ["", ""]
    @FocusState private var focusedIndex: Int?
    @State private var showRoster = false
    @State private var showPaywall = false
    @State private var saveError: String?
    @State private var contentVisible = false

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
                    .staggeredEntrance(visible: contentVisible, index: 0)

                responsiveForm
            }
            .padding(.horizontal, AppTheme.spacingMedium)
            .padding(.top, AppTheme.spacingSmall)
            .padding(.bottom, 112)
            .pipCountPageContent(maxWidth: 980)
        }
        .appBackground()
        .navigationTitle("Players")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            AppActionButton(
                role: canStart ? .primary(ClubhouseTheme.blue) : .secondary,
                action: startGame
            ) {
                Label("Continue", systemImage: "arrow.right")
            }
            .accessibilityIdentifier("start_game_button")
            .disabled(!canStart)
            .padding(.vertical, AppTheme.spacingSmall)
            .padding(.horizontal, AppTheme.spacingSmall)
            .appGlass(cornerRadius: AppTheme.cornerRadiusLarge, isInteractive: true)
            .padding(.horizontal, AppTheme.spacingMedium)
            .padding(.bottom, AppTheme.spacingSmall)
            .pipCountPageContent(maxWidth: AppTheme.formMaxWidth)
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
        .onAppear { contentVisible = true }
    }

    @ViewBuilder
    private var responsiveForm: some View {
        if horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize {
            HStack(alignment: .top, spacing: AppTheme.spacingLarge) {
                VStack(spacing: AppTheme.spacingMedium) {
                    if !recentNames.isEmpty {
                        SavedPlayersBar(
                            names: recentNames,
                            cleanedNames: cleanedNames,
                            onTap: addRosterNames
                        )
                        .staggeredEntrance(visible: contentVisible, index: 1)
                    }

                    PlayerNameFields(
                        playerNames: $playerNames,
                        focusedIndex: $focusedIndex,
                        gameType: gameType
                    )
                    .staggeredEntrance(visible: contentVisible, index: 2)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: AppTheme.spacingMedium) {
                    AddPlayerControls(
                        gameType: gameType,
                        playerCount: playerNames.count,
                        onAdd: addPlayer,
                        onRoster: { showRoster = true }
                    )

                    validationBanner
                }
                .frame(width: 330)
                .staggeredEntrance(visible: contentVisible, index: 3)
            }
        } else {
            VStack(spacing: AppTheme.spacingMedium) {
                if !recentNames.isEmpty {
                    SavedPlayersBar(
                        names: recentNames,
                        cleanedNames: cleanedNames,
                        onTap: addRosterNames
                    )
                    .staggeredEntrance(visible: contentVisible, index: 1)
                }

                PlayerNameFields(
                    playerNames: $playerNames,
                    focusedIndex: $focusedIndex,
                    gameType: gameType
                )
                .staggeredEntrance(visible: contentVisible, index: 2)

                AddPlayerControls(
                    gameType: gameType,
                    playerCount: playerNames.count,
                    onAdd: addPlayer,
                    onRoster: { showRoster = true }
                )
                .staggeredEntrance(visible: contentVisible, index: 3)

                validationBanner
                    .staggeredEntrance(visible: contentVisible, index: 4)
            }
        }
    }

    @ViewBuilder
    private var validationBanner: some View {
        if let validationMessage {
            HStack(spacing: AppTheme.spacingSmall) {
                Rectangle()
                    .fill(ClubhouseTheme.red)
                    .frame(width: 8, height: 8)
                    .rotationEffect(.degrees(45))

                Text(validationMessage)
                    .font(AppFonts.caption.weight(.semibold))
                    .foregroundStyle(ClubhouseTheme.ink)

                Spacer(minLength: 0)
            }
            .padding(AppTheme.spacingSmall)
            .background(ClubhouseTheme.red.opacity(0.07), in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                    .strokeBorder(ClubhouseTheme.red.opacity(0.22), lineWidth: 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Group {
            if horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize {
                HStack(alignment: .center, spacing: AppTheme.spacingXXLarge) {
                    copy
                        .frame(maxWidth: 360, alignment: .leading)

                    PipCountGeometricArtwork(scene: .playerSetup)
                        .frame(maxWidth: 470)
                        .frame(height: 290)
                }
            } else if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
                    copy
                    PipCountGeometricArtwork(scene: .playerSetup)
                        .frame(maxWidth: .infinity)
                        .frame(height: 210)
                }
            } else {
                HStack(alignment: .center, spacing: AppTheme.spacingMedium) {
                    copy
                        .frame(maxWidth: .infinity, alignment: .leading)

                    PipCountGeometricArtwork(scene: .playerSetup)
                        .frame(width: 166, height: 172)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var copy: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            Text("Add\nPlayers")
                .font(AppFonts.hero)
                .foregroundStyle(ClubhouseTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("Build tonight's lineup.")
                .font(AppFonts.body)
                .foregroundStyle(ClubhouseTheme.inkMuted)

            HStack(spacing: 7) {
                Rectangle()
                    .fill(gameType.color)
                    .frame(width: 9, height: 9)
                    .rotationEffect(.degrees(45))

                Text(gameType.displayName)
                    .font(AppFonts.caption.weight(.bold))
                    .foregroundStyle(gameType.color)
            }
            .padding(.top, 4)
        }
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
        .padding(AppTheme.spacingMedium)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge)
    }
}

private struct PlayerNameFields: View {
    @Binding var playerNames: [String]
    var focusedIndex: FocusState<Int?>.Binding
    let gameType: GameType
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Tonight's Players")
                        .font(AppFonts.title)
                        .foregroundStyle(ClubhouseTheme.ink)
                    Text("\(playerNames.count) of \(gameType.maxPlayers) seats filled")
                        .font(AppFonts.caption)
                        .foregroundStyle(ClubhouseTheme.inkMuted)
                }

                Spacer()

                Text("\(playerNames.count)")
                    .font(AppFonts.scoreSmall)
                    .monospacedDigit()
                    .foregroundStyle(gameType.color)
            }

            VStack(spacing: 0) {
                ForEach(playerNames.indices, id: \.self) { index in
                    PlayerNameRow(
                        name: $playerNames[index],
                        index: index,
                        canRemove: playerNames.count > 2,
                        focusedIndex: focusedIndex,
                        onRemove: { removePlayer(at: index) }
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .padding(AppTheme.spacingMedium)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge, isInteractive: true)
    }

    private func removePlayer(at index: Int) {
        if reduceMotion {
            _ = playerNames.remove(at: index)
        } else {
            withAnimation(AppMotion.state) {
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
        .frame(minHeight: 62)
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
                controlButton(
                    title: "Add Player",
                    systemImage: "plus",
                    tint: ClubhouseTheme.blue,
                    action: onAdd
                )
                .accessibilityIdentifier("add_player_button")
            }

            controlButton(
                title: "From Roster",
                systemImage: "person.2.fill",
                tint: ClubhouseTheme.yellow,
                action: onRoster
            )
            .accessibilityIdentifier("roster_button")
        }
        .frame(maxWidth: .infinity)
    }

    private func controlButton(
        title: String,
        systemImage: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemImage)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(tint == ClubhouseTheme.yellow ? ClubhouseTheme.ink : ClubhouseTheme.onPrimary)
                    .frame(width: 38, height: 38)
                    .background(tint, in: Circle())

                Text(title)
                Spacer()
                Image(systemName: "arrow.right")
            }
            .font(AppFonts.body.weight(.bold))
            .foregroundStyle(ClubhouseTheme.ink)
            .padding(.horizontal, AppTheme.spacingMedium)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 66)
            .scorecardSurface(cornerRadius: AppTheme.cornerRadiusMedium, isInteractive: true)
        }
        .buttonStyle(PressableButtonStyle())
    }
}
