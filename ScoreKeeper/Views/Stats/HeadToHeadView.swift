import SwiftData
import SwiftUI

struct HeadToHeadView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(NavigationRouter.self) private var router

    @Query(sort: \GameSession.createdAt, order: .reverse)
    private var allSessions: [GameSession]

    @State private var playerA = ""
    @State private var playerB = ""
    @State private var expandedKeys: Set<String> = []
    @State private var contentVisible = false

    private var completedSessions: [GameSession] {
        allSessions.filter(\.isComplete)
    }

    private var playerNames: [String] {
        StatsCalculator.allPlayerNames(from: completedSessions)
    }

    private var records: [H2HRecord] {
        guard !playerA.isEmpty, !playerB.isEmpty, playerA != playerB else { return [] }
        return StatsCalculator.headToHeadByGameType(playerA, vs: playerB, sessions: completedSessions)
    }

    private var hasValidSelection: Bool {
        !playerA.isEmpty && !playerB.isEmpty && playerA != playerB
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacingLarge) {
                comparisonHero
                    .staggeredEntrance(visible: contentVisible, index: 0)

                selectionPanel
                    .staggeredEntrance(visible: contentVisible, index: 1)

                comparisonContent
                    .staggeredEntrance(visible: contentVisible, index: 2)
            }
            .padding(.horizontal, AppTheme.spacingMedium)
            .padding(.top, AppTheme.spacingSmall)
            .padding(.bottom, AppTheme.spacingLarge)
            .pipCountPageContent(maxWidth: 1_080)
        }
        .appBackground()
        .navigationTitle("head to head")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            contentVisible = true
        }
        .onChange(of: playerA) { _, _ in
            expandedKeys = []
            if playerA == playerB {
                playerB = ""
            }
        }
        .onChange(of: playerB) { _, _ in
            expandedKeys = []
        }
    }

    private var comparisonHero: some View {
        Group {
            if horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize {
                HStack(alignment: .center, spacing: AppTheme.spacingXXLarge) {
                    heroCopy
                        .frame(maxWidth: 400, alignment: .leading)

                    PipCountGeometricArtwork(scene: .roster)
                        .frame(maxWidth: 500)
                        .frame(height: 300)
                }
            } else {
                HStack(alignment: .center, spacing: AppTheme.spacingMedium) {
                    heroCopy
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if !dynamicTypeSize.isAccessibilitySize {
                        PipCountGeometricArtwork(scene: .roster)
                            .frame(width: 170, height: 174)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var heroCopy: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            Text("head\nto head")
                .font(AppFonts.hero)
                .foregroundStyle(ClubhouseTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("see how two regulars have finished against each other")
                .font(AppFonts.body)
                .foregroundStyle(ClubhouseTheme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)

            Rectangle()
                .fill(ClubhouseTheme.red)
                .frame(width: 82, height: 4)
                .padding(.top, 4)
        }
    }

    private var selectionPanel: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
            VStack(alignment: .leading, spacing: 3) {
                Text("choose the matchup")
                    .font(AppFonts.title)
                    .foregroundStyle(ClubhouseTheme.ink)

                Text("pipcount compares completed games shared by both players")
                    .font(AppFonts.caption)
                    .foregroundStyle(ClubhouseTheme.inkMuted)
            }

            let layout = horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(HStackLayout(spacing: AppTheme.spacingMedium))
                : AnyLayout(VStackLayout(spacing: AppTheme.spacingSmall))

            layout {
                playerPicker(
                    title: "player one",
                    selection: $playerA,
                    names: playerNames,
                    colorIndex: 0
                )

                matchDivider

                playerPicker(
                    title: "player two",
                    selection: $playerB,
                    names: playerNames.filter { $0.caseInsensitiveCompare(playerA) != .orderedSame },
                    colorIndex: 1
                )
            }
        }
        .padding(AppTheme.spacingLarge)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge, isInteractive: true)
    }

    private func playerPicker(
        title: String,
        selection: Binding<String>,
        names: [String],
        colorIndex: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                PlayerColorPip(colorIndex: colorIndex, size: 16)
                Text(title)
                    .columnHeaderStyle()
            }

            Picker(title, selection: selection) {
                Text("select a player").tag("")
                ForEach(names, id: \.self) { name in
                    Text(name).tag(name)
                }
            }
            .pickerStyle(.menu)
            .font(AppFonts.body.weight(.semibold))
            .tint(ClubhouseTheme.ink)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .padding(.horizontal, AppTheme.spacingSmall)
            .background(ClubhouseTheme.paperSunken, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                    .strokeBorder(ClubhouseTheme.rule, lineWidth: 1)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var matchDivider: some View {
        ZStack {
            Circle()
                .fill(ClubhouseTheme.yellow)
                .frame(width: 42, height: 42)

            Text("vs")
                .font(AppFonts.caption.weight(.black))
                .foregroundStyle(ClubhouseTheme.ink)
        }
        .frame(minWidth: 48, minHeight: 48)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var comparisonContent: some View {
        if records.isEmpty {
            emptyComparison
        } else {
            LazyVGrid(columns: recordColumns, spacing: AppTheme.spacingMedium) {
                ForEach(records, id: \.id) { record in
                    recordCard(record)
                }
            }
        }
    }

    private var recordColumns: [GridItem] {
        if horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize {
            return [
                GridItem(.flexible(), spacing: AppTheme.spacingMedium, alignment: .top),
                GridItem(.flexible(), spacing: AppTheme.spacingMedium, alignment: .top)
            ]
        }

        return [GridItem(.flexible(), alignment: .top)]
    }

    private var emptyComparison: some View {
        VStack(spacing: AppTheme.spacingMedium) {
            PipCountGeometricArtwork(
                scene: hasValidSelection ? .homeEmpty : .roster,
                ambientMotion: false
            )
            .frame(width: 210, height: 180)

            Text(hasValidSelection ? "no games together" : "choose two players")
                .font(AppFonts.title)
                .foregroundStyle(ClubhouseTheme.ink)

            Text(
                hasValidSelection
                    ? "\(playerA) and \(playerB) do not have a completed matchup yet"
                    : "their shared record will appear here, separated by game type"
            )
            .font(AppFonts.body)
            .foregroundStyle(ClubhouseTheme.inkMuted)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(AppTheme.spacingLarge)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge)
    }

    private func recordCard(_ record: H2HRecord) -> some View {
        VStack(spacing: AppTheme.spacingMedium) {
            HStack(alignment: .center, spacing: AppTheme.spacingSmall) {
                GameTypeArtwork(gameType: record.gameType ?? .generic)
                    .frame(width: 54, height: 54)
                    .background(ClubhouseTheme.paperSunken, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(record.gameType?.displayName ?? "all games")
                        .font(AppFonts.headline)
                        .foregroundStyle(ClubhouseTheme.ink)
                        .lineLimit(1)

                    Text(record.gamesTogether.quantityText("game") + " together")
                        .font(AppFonts.caption)
                        .foregroundStyle(ClubhouseTheme.inkMuted)
                }

                Spacer()
            }

            winSummary(record)
            winBar(record)

            VStack(spacing: AppTheme.spacingSmall) {
                playerDisclosure(record.playerA, record: record, colorIndex: 0)
                expandableGames(for: record.playerA, record: record)
                playerDisclosure(record.playerB, record: record, colorIndex: 1)
                expandableGames(for: record.playerB, record: record)
            }
        }
        .padding(AppTheme.spacingMedium)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge)
    }

    private func winSummary(_ record: H2HRecord) -> some View {
        HStack(spacing: 0) {
            playerWinColumn(
                name: record.playerA,
                wins: record.aWins,
                rate: record.aWinRate,
                colorIndex: 0
            )

            matchDivider
                .padding(.horizontal, 4)

            playerWinColumn(
                name: record.playerB,
                wins: record.bWins,
                rate: record.bWinRate,
                colorIndex: 1
            )
        }
    }

    private func playerWinColumn(name: String, wins: Int, rate: Double, colorIndex: Int) -> some View {
        Button {
            router.push(.playerStats(name))
        } label: {
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    PlayerColorPip(colorIndex: colorIndex, size: 15)

                    Text(name)
                        .font(AppFonts.body.weight(.bold))
                        .foregroundStyle(ClubhouseTheme.ink)
                        .lineLimit(1)
                }

                Text("\(wins)")
                    .font(AppFonts.scoreMedium)
                    .monospacedDigit()
                    .foregroundStyle(PlayerColors.color(for: colorIndex))

                Text("\(wins.quantityText("win")) • \(String(format: "%.0f%%", rate * 100))")
                    .font(AppFonts.caption)
                    .foregroundStyle(ClubhouseTheme.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("\(name), \(wins.quantityText("win")), \(String(format: "%.0f percent", rate * 100))")
        .accessibilityHint("Opens player stats")
        .accessibilityIdentifier("player_stats_\(name)")
    }

    private func winBar(_ record: H2HRecord) -> some View {
        GeometryReader { proxy in
            let totalWins = record.aWins + record.bWins
            let aFraction = totalWins > 0 ? CGFloat(record.aWins) / CGFloat(totalWins) : 0.5
            let gap: CGFloat = 5
            let availableWidth = max(proxy.size.width - gap, 0)

            HStack(spacing: gap) {
                Rectangle()
                    .fill(ClubhouseTheme.blue)
                    .frame(width: max(availableWidth * aFraction, totalWins == 0 ? availableWidth / 2 : 5))

                Rectangle()
                    .fill(ClubhouseTheme.red)
                    .frame(width: max(availableWidth * (1 - aFraction), totalWins == 0 ? availableWidth / 2 : 5))
            }
            .clipShape(Capsule())
            .animation(reduceMotion ? AppMotion.fade : AppMotion.state, value: aFraction)
        }
        .frame(height: 18)
        .accessibilityHidden(true)
    }

    private func playerDisclosure(
        _ name: String,
        record: H2HRecord,
        colorIndex: Int
    ) -> some View {
        Button {
            toggleExpanded(player: name, record: record)
        } label: {
            HStack(spacing: AppTheme.spacingSmall) {
                PlayerColorPip(colorIndex: colorIndex, size: 14)

                Text(name)
                    .font(AppFonts.body.weight(.semibold))
                    .foregroundStyle(ClubhouseTheme.ink)
                    .lineLimit(1)

                Spacer()

                Text("recent games")
                    .font(AppFonts.caption)
                    .foregroundStyle(ClubhouseTheme.inkMuted)

                Image(systemName: isExpanded(player: name, record: record) ? "chevron.down" : "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(ClubhouseTheme.inkMuted)
            }
            .padding(.horizontal, AppTheme.spacingSmall)
            .frame(minHeight: 48)
            .background(ClubhouseTheme.paperSunken, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("\(name) recent \(record.gameType?.displayName ?? "games")")
    }

    @ViewBuilder
    private func expandableGames(for player: String, record: H2HRecord) -> some View {
        if isExpanded(player: player, record: record), let gameType = record.gameType {
            let games = StatsCalculator.gamesBetween(
                record.playerA,
                and: record.playerB,
                gameType: gameType,
                sessions: completedSessions
            )

            VStack(alignment: .leading, spacing: 6) {
                ForEach(games.prefix(5)) { session in
                    Button {
                        router.push(.gameDetail(session.persistentModelID))
                    } label: {
                        recentGameRow(session, highlightedPlayer: player)
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            .padding(.vertical, 4)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private func recentGameRow(_ session: GameSession, highlightedPlayer: String) -> some View {
        let engine = GameEngineFactory.engine(for: session.gameType)
        let winnerIDs = Set(engine.winners(session: session))
        let player = session.players.first {
            $0.name.caseInsensitiveCompare(highlightedPlayer) == .orderedSame
        }
        let isWinner = player.map { winnerIDs.contains($0.id) } ?? false
        let outcome = isWinner ? "win" : winnerIDs.isEmpty ? "no winner" : "finished"

        return HStack(spacing: AppTheme.spacingSmall) {
            Rectangle()
                .fill(isWinner ? ClubhouseTheme.green : ClubhouseTheme.inkMuted)
                .frame(width: 8, height: 8)
                .rotationEffect(.degrees(45))

            Text(ShortDate.string(from: session.completedAt ?? session.createdAt))
                .font(AppFonts.caption)
                .foregroundStyle(ClubhouseTheme.inkMuted)

            Spacer()

            Text(outcome)
                .font(AppFonts.caption.weight(.bold))
                .foregroundStyle(isWinner ? ClubhouseTheme.green : ClubhouseTheme.inkMuted)

            if let player {
                Text("\(player.totalScore(in: session))")
                    .font(AppFonts.scoreSmall)
                    .monospacedDigit()
                    .foregroundStyle(ClubhouseTheme.ink)
            }

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.bold))
                .foregroundStyle(ClubhouseTheme.inkMuted)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, AppTheme.spacingSmall)
        .background(ClubhouseTheme.paperCard, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                .strokeBorder(ClubhouseTheme.rule, lineWidth: 1)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func key(player: String, record: H2HRecord) -> String {
        "\(record.gameType?.rawValue ?? "all"):\(player)"
    }

    private func isExpanded(player: String, record: H2HRecord) -> Bool {
        expandedKeys.contains(key(player: player, record: record))
    }

    private func toggleExpanded(player: String, record: H2HRecord) {
        let expansionKey = key(player: player, record: record)

        withAnimation(reduceMotion ? AppMotion.fade : AppMotion.state) {
            if expandedKeys.contains(expansionKey) {
                expandedKeys.remove(expansionKey)
            } else {
                expandedKeys.insert(expansionKey)
            }
        }
    }
}
