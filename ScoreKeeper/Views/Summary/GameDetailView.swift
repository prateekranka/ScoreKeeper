import SwiftData
import SwiftUI

struct GameDetailView: View {
    let sessionID: PersistentIdentifier

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var contentVisible = false

    var body: some View {
        SessionLoader(sessionID: sessionID) { session in
            let engine = GameEngineFactory.engine(for: session.gameType)

            GeometryReader { proxy in
                ScrollView {
                    if proxy.size.width >= 820 && !dynamicTypeSize.isAccessibilitySize {
                        tabletLayout(session: session, engine: engine, availableWidth: proxy.size.width)
                    } else {
                        phoneLayout(session: session, engine: engine)
                    }
                }
                .scrollIndicators(.hidden)
            }
            .accessibilityIdentifier("game_detail_view")
            .appBackground()
            .navigationTitle("game details")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if reduceMotion {
                    contentVisible = true
                } else {
                    withAnimation(AppMotion.page) {
                        contentVisible = true
                    }
                }
            }
        }
    }

    private func phoneLayout(session: GameSession, engine: GameEngine) -> some View {
        VStack(spacing: AppTheme.spacingMedium) {
            detailHero(session: session, engine: engine)
                .staggeredEntrance(visible: contentVisible, index: 0)

            standingsPanel(session: session, engine: engine)
                .staggeredEntrance(visible: contentVisible, index: 1)

            summaryPanel(session: session, engine: engine)
                .staggeredEntrance(visible: contentVisible, index: 2)

            RoundBreakdownSection(session: session)
                .staggeredEntrance(visible: contentVisible, index: 3)

            shareButton(session: session, engine: engine)
                .staggeredEntrance(visible: contentVisible, index: 4)
        }
        .padding(.horizontal, AppTheme.spacingMedium)
        .padding(.top, AppTheme.spacingSmall)
        .padding(.bottom, AppTheme.spacingLarge)
        .pipCountPageContent(maxWidth: AppTheme.formMaxWidth)
    }

    private func tabletLayout(
        session: GameSession,
        engine: GameEngine,
        availableWidth: CGFloat
    ) -> some View {
        VStack(spacing: AppTheme.spacingLarge) {
            detailHero(session: session, engine: engine)
                .staggeredEntrance(visible: contentVisible, index: 0)

            HStack(alignment: .top, spacing: AppTheme.spacingLarge) {
                VStack(spacing: AppTheme.spacingMedium) {
                    standingsPanel(session: session, engine: engine)
                        .staggeredEntrance(visible: contentVisible, index: 1)

                    summaryPanel(session: session, engine: engine)
                        .staggeredEntrance(visible: contentVisible, index: 2)

                    shareButton(session: session, engine: engine)
                        .staggeredEntrance(visible: contentVisible, index: 4)
                }
                .frame(width: min(max(availableWidth * 0.34, 340), 430), alignment: .top)

                RoundBreakdownSection(session: session)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .staggeredEntrance(visible: contentVisible, index: 3)
            }
        }
        .padding(.horizontal, AppTheme.spacingXLarge)
        .padding(.top, AppTheme.spacingMedium)
        .padding(.bottom, AppTheme.spacingXLarge)
        .frame(maxWidth: min(availableWidth, 1_180), alignment: .top)
        .frame(maxWidth: .infinity)
    }

    private func detailHero(session: GameSession, engine: GameEngine) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
                    detailHeroCopy(session: session, engine: engine)
                    PipCountGeometricArtwork(scene: .gameOver)
                        .frame(maxWidth: .infinity)
                        .frame(height: 230)
                }
            } else {
                HStack(alignment: .center, spacing: AppTheme.spacingLarge) {
                    detailHeroCopy(session: session, engine: engine)
                        .frame(maxWidth: 430, alignment: .leading)

                    PipCountGeometricArtwork(scene: .gameOver)
                        .frame(maxWidth: .infinity)
                        .frame(height: 285)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func detailHeroCopy(session: GameSession, engine: GameEngine) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            StampBadge(text: "final")

            Text(session.gameType.displayName)
                .font(AppFonts.display)
                .foregroundStyle(ClubhouseTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.62)

            Text(resultTitle(session: session, engine: engine))
                .font(AppFonts.title)
                .foregroundStyle(ClubhouseTheme.blue)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(completionDate(session))
                .font(AppFonts.body)
                .foregroundStyle(ClubhouseTheme.inkMuted)

            Rectangle()
                .fill(ClubhouseTheme.green)
                .frame(width: 88, height: 5)
                .padding(.top, 3)
        }
    }

    private func standingsPanel(session: GameSession, engine: GameEngine) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
            VStack(alignment: .leading, spacing: 3) {
                Text("final standings")
                    .font(AppFonts.title)
                    .foregroundStyle(ClubhouseTheme.ink)

                Text(session.winCondition == .highestScore ? "highest score wins" : "lowest score wins")
                    .font(AppFonts.caption)
                    .foregroundStyle(ClubhouseTheme.inkMuted)
            }

            StandingsList(title: "scores", standings: session.standings(using: engine))
        }
    }

    private func summaryPanel(session: GameSession, engine: GameEngine) -> some View {
        let metrics = detailMetrics(session: session, engine: engine)

        return VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            Text("at a glance")
                .font(AppFonts.title)
                .foregroundStyle(ClubhouseTheme.ink)

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: AppTheme.spacingSmall
            ) {
                ForEach(metrics) { metric in
                    DetailMetricCard(metric: metric)
                }
            }
        }
        .padding(AppTheme.spacingMedium)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge)
    }

    @ViewBuilder
    private func shareButton(session: GameSession, engine: GameEngine) -> some View {
        if let shareImage = ScorecardShareCard.shareImage(session: session, engine: engine) {
            ShareLink(item: shareImage, preview: SharePreview("pipcount scorecard", image: shareImage)) {
                shareLabel
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityIdentifier("share_game_detail_button")
        } else {
            ShareLink(item: shareText(session: session, engine: engine)) {
                shareLabel
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityIdentifier("share_game_detail_button")
        }
    }

    private var shareLabel: some View {
        HStack(spacing: AppTheme.spacingSmall) {
            Image(systemName: "square.and.arrow.up")
                .font(.headline.weight(.semibold))

            Text("share final scorecard")
                .font(AppFonts.headline)

            Spacer()

            Image(systemName: "arrow.up.right")
                .font(.caption.weight(.bold))
        }
        .foregroundStyle(ClubhouseTheme.ink)
        .padding(.horizontal, AppTheme.spacingMedium)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 58)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusMedium, isInteractive: true)
    }

    private func resultTitle(session: GameSession, engine: GameEngine) -> String {
        let winnerIDs = Set(engine.winners(session: session))
        let names = session.players.filter { winnerIDs.contains($0.id) }.map(\.name)

        if names.count == 1 {
            return "\(names[0]) won"
        }
        if names.count > 1 {
            return "tie: \(names.joined(separator: " & "))"
        }
        return "no winner"
    }

    private func completionDate(_ session: GameSession) -> String {
        let date = session.completedAt ?? session.createdAt
        let weekday = date.formatted(.dateTime.weekday(.abbreviated)).lowercased()
        let day = date.formatted(.dateTime.day())
        let month = date.formatted(.dateTime.month(.abbreviated)).lowercased()
        let year = date.formatted(.dateTime.year())
        return "\(weekday), \(day) \(month) \(year)"
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

    private func detailMetrics(session: GameSession, engine: GameEngine) -> [DetailMetric] {
        let duration = session.completedAt?.timeIntervalSince(session.createdAt) ?? 0
        let winnerIDs = Set(engine.winners(session: session))
        let winningPlayer = sortedPlayers(session).first { winnerIDs.contains($0.id) }

        return [
            DetailMetric(
                title: "rounds",
                value: "\(session.sortedRounds.count)",
                detail: "played",
                tint: ClubhouseTheme.blue
            ),
            DetailMetric(
                title: "players",
                value: "\(session.players.count)",
                detail: "at the table",
                tint: ClubhouseTheme.red
            ),
            DetailMetric(
                title: "winning score",
                value: winningPlayer.map { "\($0.totalScore(in: session))" } ?? "—",
                detail: winningPlayer?.name ?? "no winner",
                tint: ClubhouseTheme.yellow
            ),
            DetailMetric(
                title: "duration",
                value: durationText(duration),
                detail: "game time",
                tint: ClubhouseTheme.ink
            )
        ]
    }

    private func durationText(_ interval: TimeInterval) -> String {
        guard interval > 0 else { return "—" }

        let minutes = max(Int(interval / 60), 1)
        let hours = minutes / 60
        let remainder = minutes % 60

        if hours > 0 {
            return remainder == 0 ? "\(hours)h" : "\(hours)h \(remainder)m"
        }
        return "\(minutes)m"
    }

    private func shareText(session: GameSession, engine: GameEngine) -> String {
        let standings = sortedPlayers(session).enumerated().map { index, player in
            "\(index + 1). \(player.name) — \(player.totalScore(in: session))"
        }
        .joined(separator: "\n")

        return "pipcount — \(session.gameType.displayName)\n\(resultTitle(session: session, engine: engine))\n\(standings)\n\(session.sortedRounds.count.quantityText("round")) played"
    }
}

private struct RoundBreakdownSection: View {
    let session: GameSession

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        if session.sortedRounds.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: AppTheme.spacingMedium) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("round by round")
                            .font(AppFonts.title)
                            .foregroundStyle(ClubhouseTheme.ink)

                        Text("every submitted score, in order")
                            .font(AppFonts.caption)
                            .foregroundStyle(ClubhouseTheme.inkMuted)
                    }

                    Spacer()

                    Text(session.sortedRounds.count.quantityText("round"))
                        .columnHeaderStyle()
                        .foregroundStyle(ClubhouseTheme.blue)
                }

                LazyVGrid(columns: columns, spacing: AppTheme.spacingSmall) {
                    ForEach(session.sortedRounds, id: \.id) { round in
                        RoundCard(round: round, players: session.players)
                    }
                }
            }
            .padding(AppTheme.spacingMedium)
            .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge)
        }
    }

    private var columns: [GridItem] {
        if horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize {
            return [
                GridItem(.flexible(), spacing: AppTheme.spacingSmall, alignment: .top),
                GridItem(.flexible(), spacing: AppTheme.spacingSmall, alignment: .top)
            ]
        }

        return [GridItem(.flexible(), alignment: .top)]
    }
}

private struct RoundCard: View {
    let round: Round
    let players: [Player]

    private var highestMagnitude: Int {
        max(round.entries.map { abs($0.points) }.max() ?? 0, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            HStack {
                Text("round \(round.roundNumber)")
                    .font(AppFonts.headline)
                    .foregroundStyle(ClubhouseTheme.ink)
                    .monospacedDigit()

                Spacer()

                Rectangle()
                    .fill(round.roundNumber.isMultiple(of: 2) ? ClubhouseTheme.red : ClubhouseTheme.blue)
                    .frame(width: 12, height: 12)
                    .rotationEffect(.degrees(45))
                    .accessibilityHidden(true)
            }

            Rectangle()
                .fill(ClubhouseTheme.rule)
                .frame(height: 1)

            ForEach(players, id: \.id) { player in
                let points = round.entry(for: player.id)?.points ?? 0

                VStack(spacing: 5) {
                    HStack(spacing: AppTheme.spacingSmall) {
                        BauhausPlayerShape(colorIndex: player.colorIndex, size: 18)

                        Text(player.name)
                            .font(AppFonts.caption.weight(.semibold))
                            .foregroundStyle(ClubhouseTheme.ink)
                            .lineLimit(1)

                        Spacer()

                        Text(points > 0 ? "+\(points)" : "\(points)")
                            .font(AppFonts.caption.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(ClubhouseTheme.ink)
                            .contentTransition(.numericText(value: Double(points)))
                    }

                    GeometryReader { proxy in
                        Rectangle()
                            .fill(PlayerColors.color(for: player.colorIndex).opacity(0.78))
                            .frame(
                                width: max(
                                    4,
                                    proxy.size.width * CGFloat(abs(points)) / CGFloat(highestMagnitude)
                                )
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 4)
                    .background(ClubhouseTheme.rule.opacity(0.55))
                }
            }
        }
        .padding(AppTheme.spacingSmall)
        .frame(maxWidth: .infinity, minHeight: 154, alignment: .topLeading)
        .background(ClubhouseTheme.paperSunken, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                .strokeBorder(ClubhouseTheme.rule, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct DetailMetric: Identifiable {
    let title: String
    let value: String
    let detail: String
    let tint: Color

    var id: String { title }
}

private struct DetailMetricCard: View {
    let metric: DetailMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Rectangle()
                .fill(metric.tint)
                .frame(width: 10, height: 10)
                .rotationEffect(.degrees(45))

            Text(metric.value)
                .font(AppFonts.scoreMedium)
                .monospacedDigit()
                .foregroundStyle(ClubhouseTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.58)

            Text(metric.title)
                .font(AppFonts.caption.weight(.bold))
                .foregroundStyle(ClubhouseTheme.ink)
                .lineLimit(2)

            Text(metric.detail)
                .font(AppFonts.caption)
                .foregroundStyle(ClubhouseTheme.inkMuted)
                .lineLimit(1)
        }
        .padding(AppTheme.spacingSmall)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .background(ClubhouseTheme.paperSunken, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                .strokeBorder(ClubhouseTheme.rule, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}
