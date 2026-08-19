import SwiftUI
import SwiftData
import PencilKit
import Vision

struct GenericScoringView: View {
    @Bindable var session: GameSession
    @Environment(\.modelContext) private var modelContext
    @Environment(NavigationRouter.self) private var router
    @Environment(StoreManager.self) private var storeManager
    @Environment(ReviewAskManager.self) private var reviewAskManager
    @State private var scores: [UUID: Int] = [:]
    @State private var scoreHapticTrigger = 0
    @State private var saveError: String?
    @State private var didRouteToGameOver = false
    @State private var showsRoundEntry = false
    private let engine = GenericEngine()

    var body: some View {
        ScoringScreenLayout(
            session: session,
            engine: engine,
            actionTitle: "End Round & Write Scores",
            actionSystemImage: "pencil.and.outline",
            showsScoreboardHeader: false,
            headerStyle: .compact,
            showsToolsBar: false,
            action: endRound
        ) {
            CompactRoundScoreTable(
                session: session,
                engine: engine,
                scores: scoreBinding(for:),
                winConditionLabel: session.winCondition == .highestScore ? "Highest wins" : "Lowest wins"
            )
        } footer: {
            RoundHistoryStrip(session: session)
        }
        .sensoryFeedback(.impact, trigger: scoreHapticTrigger)
        .fullScreenCover(isPresented: $showsRoundEntry) {
            HandwrittenRoundEntryView(
                players: session.players,
                roundNumber: session.currentRoundNumber,
                currentTotals: Dictionary(uniqueKeysWithValues: session.players.map { ($0.id, $0.totalScore(in: session)) }),
                initialScores: scores,
                onCancel: { showsRoundEntry = false },
                onComplete: { capturedScores in
                    showsRoundEntry = false
                    scores = capturedScores
                    submitRound(using: capturedScores)
                }
            )
        }
        .alert(
            "Couldn’t save round",
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

    private func scoreBinding(for player: Player) -> Binding<Int> {
        Binding(
            get: { scores[player.id] ?? 0 },
            set: { scores[player.id] = $0 }
        )
    }

    private func endRound() {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-in-memory-store") && !arguments.contains("-force-handwriting-entry") {
            submitRound(using: scores)
        } else {
            showsRoundEntry = true
        }
    }

    private func submitRound(using roundScores: [UUID: Int]) {
        let round = Round(roundNumber: session.currentRoundNumber)
        round.session = session

        for player in session.players {
            let points = roundScores[player.id] ?? 0
            let entry = ScoreEntry(playerID: player.id, points: points)
            entry.round = round
            round.entries.append(entry)
        }

        session.rounds.append(round)

        do {
            try modelContext.save()
        } catch {
            let message = error.localizedDescription
            modelContext.rollback()
            saveError = message
            return
        }

        // Reset scores
        scores = [:]

        scoreHapticTrigger += 1

        if engine.isGameOver(session: session) {
            finishGame()
        }
    }

    private func finishGame() {
        guard !didRouteToGameOver else { return }

        session.isComplete = true
        session.completedAt = .now
        session.winnerID = engine.winners(session: session).first

        do {
            try modelContext.save()
        } catch {
            let message = error.localizedDescription
            modelContext.rollback()
            saveError = message
            return
        }

        didRouteToGameOver = true
        let completedGameCount = fetchCompletedGameCount()
        let paywallPresentedThisSession = storeManager.paywallPresentedThisSession
        router.push(.gameOver(session.persistentModelID))

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1_000))
            reviewAskManager.considerReviewAsk(
                completedGameCount: completedGameCount,
                paywallPresentedThisSession: paywallPresentedThisSession
            )
        }
    }

    private func fetchCompletedGameCount() -> Int {
        let descriptor = FetchDescriptor<GameSession>(predicate: #Predicate { $0.isComplete })
        return (try? modelContext.fetch(descriptor).count) ?? 0
    }
}

private struct CompactRoundScoreTable: View {
    let session: GameSession
    let engine: GameEngine
    let scores: (Player) -> Binding<Int>
    let winConditionLabel: String

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Players")
                        .font(AppFonts.title)
                        .foregroundStyle(ClubhouseTheme.ink)
                    Text("Tap End Round, then write each score with your finger.")
                        .font(AppFonts.caption)
                        .foregroundStyle(ClubhouseTheme.inkMuted)
                }

                Spacer(minLength: AppTheme.spacingSmall)

                Text(winConditionLabel)
                    .columnHeaderStyle()
                    .foregroundStyle(ClubhouseTheme.blue)
            }
            .padding(AppTheme.spacingMedium)

            Rectangle()
                .fill(ClubhouseTheme.rule)
                .frame(height: 1)

            ForEach(Array(session.players.enumerated()), id: \.element.id) { index, player in
                CompactRoundScoreRow(
                    player: player,
                    totalScore: player.totalScore(in: session),
                    isLeading: leadingPlayers.contains(player.id),
                    value: scores(player)
                )

                if index < session.players.count - 1 {
                    Rectangle()
                        .fill(ClubhouseTheme.rule)
                        .frame(height: 1)
                        .padding(.leading, 64)
                }
            }
        }
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge, isInteractive: true)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Round \(session.currentRoundNumber) players, \(winConditionLabel)")
    }

    private var leadingPlayers: [UUID] {
        session.rounds.isEmpty ? [] : engine.winners(session: session)
    }
}

private struct CompactRoundScoreRow: View {
    let player: Player
    let totalScore: Int
    let isLeading: Bool
    @Binding var value: Int

    var body: some View {
        HStack(spacing: AppTheme.spacingSmall) {
            BauhausPlayerShape(colorIndex: player.colorIndex, size: 38)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(player.name)
                        .font(AppFonts.headline)
                        .foregroundStyle(ClubhouseTheme.ink)
                        .lineLimit(1)
                    if isLeading {
                        BrassCrown()
                            .accessibilityLabel("Leading")
                    }
                }

                Text("Total \(totalScore)")
                    .font(AppFonts.caption)
                    .foregroundStyle(isLeading ? ClubhouseTheme.brass : ClubhouseTheme.inkMuted)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            CompactScoreStepper(
                value: $value,
                range: -9999...9999,
                step: 1,
                identifierPrefix: "\(player.name)_"
            )
            .frame(width: 160)
        }
        .padding(.horizontal, AppTheme.spacingMedium)
        .padding(.vertical, 9)
        .background(value == 0 ? Color.clear : PlayerColors.lightColor(for: player.colorIndex))
        .animation(AppMotion.state, value: value == 0)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(player.name), total score \(totalScore), round score \(value)")
    }
}

private struct GenericFocusScoreTable: View {
    let session: GameSession
    let engine: GameEngine
    let scores: (Player) -> Binding<Int>
    let winConditionLabel: String

    var body: some View {
        VStack(spacing: 0) {
            header

            Rectangle()
                .fill(ClubhouseTheme.rule)
                .frame(height: 1)
                .padding(.horizontal, AppTheme.spacingMedium)

            VStack(spacing: 0) {
                tableHeader

                ForEach(Array(session.players.enumerated()), id: \.element.id) { index, player in
                    FocusScoreRow(
                        player: player,
                        totalScore: player.totalScore(in: session),
                        isLeading: leadingPlayers.contains(player.id),
                        value: scores(player)
                    )

                    if index < session.players.count - 1 {
                        Rectangle()
                            .fill(ClubhouseTheme.rule)
                            .frame(height: 1)
                            .padding(.leading, 76)
                    }
                }
            }
            .padding(.horizontal, AppTheme.spacingMedium)
            .padding(.bottom, AppTheme.spacingMedium)
        }
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge, isInteractive: true)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Round \(session.currentRoundNumber) score table, \(winConditionLabel)")
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppTheme.spacingSmall) {
            Label("Round \(session.currentRoundNumber)", systemImage: session.gameType.icon)
                .font(AppFonts.title)
                .foregroundStyle(ClubhouseTheme.ink)
                .monospacedDigit()

            Spacer(minLength: AppTheme.spacingSmall)

            Text(winConditionLabel)
                .columnHeaderStyle()
                .padding(.horizontal, 10)
                .frame(minHeight: 28)
                .background(ClubhouseTheme.paperSunken, in: Capsule())
                .overlay { Capsule().strokeBorder(ClubhouseTheme.rule, lineWidth: 1) }
        }
        .padding(AppTheme.spacingMedium)
    }

    private var tableHeader: some View {
        HStack {
            Text("Player")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Total")
                .frame(width: 64, alignment: .trailing)
        }
        .columnHeaderStyle()
        .padding(.vertical, AppTheme.spacingSmall)
    }

    private var leadingPlayers: [UUID] {
        session.rounds.isEmpty ? [] : engine.winners(session: session)
    }
}

private struct FocusScoreRow: View {
    let player: Player
    let totalScore: Int
    let isLeading: Bool
    @Binding var value: Int
    var range: ClosedRange<Int> = -9999...9999
    var step = 1

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: AppTheme.spacingSmall) {
                playerIdentity

                Spacer(minLength: AppTheme.spacingSmall)

                totalColumn
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                    quickButtons
                    Spacer(minLength: 4)
                    scoreStepper
                }

                VStack(alignment: .trailing, spacing: AppTheme.spacingSmall) {
                    HStack(spacing: 6) {
                        quickButtons
                    }
                    scoreStepper
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 10)
        .background(value == 0 ? Color.clear : PlayerColors.lightColor(for: player.colorIndex))
        .animation(AppMotion.state, value: value == 0)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(player.name), total score \(totalScore), round score \(value)")
    }

    private var playerIdentity: some View {
        HStack(spacing: AppTheme.spacingSmall) {
            BauhausPlayerShape(colorIndex: player.colorIndex, size: 50)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    PlayerGlyph(colorIndex: player.colorIndex, font: AppFonts.caption)

                    Text(player.name)
                        .font(AppFonts.headline)
                        .foregroundStyle(ClubhouseTheme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .layoutPriority(1)

                    if isLeading {
                        BrassCrown()
                            .fixedSize()
                            .accessibilityLabel("Leading")
                    }
                }
                .layoutPriority(1)

                Text("Round points")
                    .font(AppFonts.caption)
                    .foregroundStyle(ClubhouseTheme.inkMuted)
            }
            .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .layoutPriority(2)
    }

    private var totalColumn: some View {
        Text("\(totalScore)")
            .font(AppFonts.scoreMedium)
            .monospacedDigit()
            .foregroundStyle(isLeading ? ClubhouseTheme.brass : ClubhouseTheme.ink)
            .contentTransition(.numericText(value: Double(totalScore)))
        .frame(width: 64, alignment: .trailing)
    }

    private var scoreStepper: some View {
        CompactScoreStepper(value: $value, range: range, step: step, identifierPrefix: identifierPrefix)
            .frame(width: 160, alignment: .trailing)
    }

    @ViewBuilder
    private var quickButtons: some View {
        ForEach(quickAmounts, id: \.self) { amount in
            quickButton(amount)
        }
    }

    private func quickButton(_ amount: Int) -> some View {
        Button("+\(amount)") {
            apply(amount)
        }
        .font(AppFonts.caption)
        .monospacedDigit()
        .foregroundStyle(ClubhouseTheme.ink)
        .padding(.horizontal, 9)
        .frame(minHeight: 30)
        .background(ClubhouseTheme.paperSunken, in: RoundedRectangle(cornerRadius: 5))
        .overlay { RoundedRectangle(cornerRadius: 5).strokeBorder(ClubhouseTheme.ruleStrong, lineWidth: 1) }
        .buttonStyle(PressableButtonStyle())
        .accessibilityIdentifier(identifierPrefix + "quick_\(amount)")
        .accessibilityLabel("Add \(amount) points")
    }

    private var identifierPrefix: String {
        "\(player.name)_"
    }

    private var quickAmounts: [Int] {
        Array(Set([step, step * 5, step * 10])).sorted()
    }

    private func apply(_ delta: Int) {
        let newValue = value + delta
        if range.contains(newValue) {
            value = newValue
        }
    }
}

private struct CompactScoreStepper: View {
    @Binding var value: Int
    var range: ClosedRange<Int>
    var step: Int
    var identifierPrefix: String

    var body: some View {
        HStack(spacing: 6) {
            stepButton(systemImage: "minus", delta: -step, identifier: "decrement", label: "Decrease score")

            VStack(spacing: 0) {
                Text("RD")
                    .font(AppFonts.caption)
                    .foregroundStyle(ClubhouseTheme.inkMuted)

                Text(roundScoreText)
                    .font(AppFonts.scoreSmall)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .contentTransition(.numericText(value: Double(value)))
                    .foregroundStyle(ClubhouseTheme.ink)
            }
            .frame(width: 58)
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier(identifierPrefix + "score")
            .accessibilityLabel("Score \(value)")

            stepButton(systemImage: "plus", delta: step, identifier: "increment", label: "Increase score")
        }
    }

    private func stepButton(systemImage: String, delta: Int, identifier: String, label: String) -> some View {
        Button {
            apply(delta)
        } label: {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(systemImage == "plus" ? ClubhouseTheme.blue : ClubhouseTheme.red)
                .frame(width: 44, height: 44)
                .background(ClubhouseTheme.paperCard, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                        .strokeBorder(ClubhouseTheme.ruleStrong, lineWidth: 1.25)
                }
        }
        .buttonStyle(ClubhousePressableButtonStyle())
        .accessibilityIdentifier(identifierPrefix + identifier)
        .accessibilityLabel(label)
    }

    private func apply(_ delta: Int) {
        let newValue = value + delta
        if range.contains(newValue) {
            value = newValue
        }
    }

    private var roundScoreText: String {
        value >= 0 ? "+\(value)" : "\(value)"
    }
}

private struct HandwrittenRoundEntryView: View {
    let players: [Player]
    let roundNumber: Int
    let currentTotals: [UUID: Int]
    let initialScores: [UUID: Int]
    let onCancel: () -> Void
    let onComplete: ([UUID: Int]) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var playerIndex = 0
    @State private var capturedScores: [UUID: Int]
    @State private var drawing = PKDrawing()
    @State private var drawingRevision = 0
    @State private var manualScore = ""
    @State private var isRecognizing = false
    @State private var acceptedTrigger = 0

    init(
        players: [Player],
        roundNumber: Int,
        currentTotals: [UUID: Int],
        initialScores: [UUID: Int],
        onCancel: @escaping () -> Void,
        onComplete: @escaping ([UUID: Int]) -> Void
    ) {
        self.players = players
        self.roundNumber = roundNumber
        self.currentTotals = currentTotals
        self.initialScores = initialScores
        self.onCancel = onCancel
        self.onComplete = onComplete
        _capturedScores = State(initialValue: initialScores)
        _manualScore = State(initialValue: initialScores[players.first?.id ?? UUID()].map(String.init) ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.spacingMedium) {
                    progressHeader
                    playerHeader
                    scoreSheet
                }
                .padding(.horizontal, AppTheme.spacingMedium)
                .padding(.bottom, 96)
            }
            .scrollDismissesKeyboard(.interactively)
            .appBackground()
            .navigationTitle("Round \(roundNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: onCancel)
                }
            }
            .safeAreaInset(edge: .bottom) {
                acceptButton
                    .padding(.horizontal, AppTheme.spacingMedium)
                    .padding(.vertical, AppTheme.spacingSmall)
                    .background(.bar)
            }
        }
        .sensoryFeedback(.selection, trigger: acceptedTrigger)
        .task(id: drawingRevision) {
            guard drawingRevision > 0, !drawing.strokes.isEmpty else { return }
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            await recognizeDrawing()
        }
    }

    private var currentPlayer: Player {
        players[playerIndex]
    }

    private var progressHeader: some View {
        VStack(spacing: 7) {
            HStack {
                Spacer()
                Text("\(playerIndex + 1) of \(players.count)")
                    .font(AppFonts.caption.weight(.bold))
                    .foregroundStyle(ClubhouseTheme.inkMuted)
                    .monospacedDigit()
            }

            ProgressView(value: Double(playerIndex + 1), total: Double(players.count))
                .tint(ClubhouseTheme.blue)
        }
    }

    private var playerHeader: some View {
        HStack(spacing: AppTheme.spacingMedium) {
            BauhausPlayerShape(colorIndex: currentPlayer.colorIndex, size: 64)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(currentPlayer.name)
                    .font(AppFonts.title)
                    .foregroundStyle(ClubhouseTheme.ink)
                    .lineLimit(1)

                Text("Current total: \(currentTotals[currentPlayer.id] ?? 0)")
                    .font(AppFonts.body)
                    .foregroundStyle(ClubhouseTheme.inkMuted)
                    .monospacedDigit()
            }

            Spacer(minLength: AppTheme.spacingSmall)

            PipCountGeometricArtwork(scene: .handwriting)
                .frame(width: 88, height: 74)
        }
        .id(currentPlayer.id)
        .transition(
            reduceMotion
                ? .opacity
                : .asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                )
        )
    }

    private var scoreSheet: some View {
        ZStack(alignment: .topTrailing) {
            HandwritingCanvas(drawing: $drawing) {
                drawingRevision &+= 1
            }
            .accessibilityLabel("Handwriting area for \(currentPlayer.name)'s score")

            recognitionBadge
                .padding(12)
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, minHeight: 430)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                .strokeBorder(Color.black.opacity(0.72), lineWidth: 1.5)
        }
        .padding(AppTheme.spacingSmall)
        .background(ClubhouseTheme.yellow.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
    }

    @ViewBuilder
    private var recognitionBadge: some View {
        if isRecognizing {
            ProgressView()
                .tint(ClubhouseTheme.blue)
                .padding(10)
                .background(.white.opacity(0.92), in: Capsule())
                .accessibilityLabel("Reading handwriting")
        } else if let score = parsedScore {
            Text("\(score)")
                .font(AppFonts.title)
                .foregroundStyle(ClubhouseTheme.green)
                .monospacedDigit()
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(.white.opacity(0.92), in: Capsule())
                .overlay { Capsule().strokeBorder(ClubhouseTheme.green.opacity(0.45), lineWidth: 1) }
                .accessibilityLabel("Recognized score \(score)")
        }
    }

    private var acceptButton: some View {
        AppActionButton(role: parsedScore == nil ? .secondary : .primary(ClubhouseTheme.blue), action: acceptScore) {
            Text("Next Player")
        }
        .disabled(parsedScore == nil)
        .accessibilityIdentifier("accept_handwritten_score_button")
    }

    private var parsedScore: Int? {
        HandwritingScoreRecognizer.parse(manualScore)
    }

    private func recognizeDrawing() async {
        guard let imageData = drawingImageData else { return }
        isRecognizing = true
        let score = await HandwritingScoreRecognizer.recognize(imageData)
        guard !Task.isCancelled else { return }
        if let score {
            manualScore = String(score)
        }
        isRecognizing = false
    }

    private var drawingImageData: Data? {
        guard !drawing.strokes.isEmpty else { return nil }
        let bounds = drawing.bounds.insetBy(dx: -24, dy: -24)
        return drawing.image(from: bounds, scale: 2).pngData()
    }

    private func acceptScore() {
        guard let score = parsedScore else { return }
        var nextScores = capturedScores
        nextScores[currentPlayer.id] = score
        capturedScores = nextScores
        acceptedTrigger &+= 1

        guard playerIndex < players.count - 1 else {
            onComplete(nextScores)
            return
        }

        let nextIndex = playerIndex + 1
        withAnimation(reduceMotion ? AppMotion.fade : AppMotion.page) {
            playerIndex = nextIndex
        }
        drawing = PKDrawing()
        manualScore = nextScores[players[nextIndex].id].map(String.init) ?? ""
        isRecognizing = false
    }
}

private struct HandwritingCanvas: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    let onDrawingChanged: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(drawing: $drawing, onDrawingChanged: onDrawingChanged)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.delegate = context.coordinator
        canvas.drawingPolicy = .anyInput
        canvas.tool = PKInkingTool(.pen, color: .black, width: 9)
        canvas.backgroundColor = .white
        canvas.isOpaque = true
        canvas.alwaysBounceVertical = false
        canvas.alwaysBounceHorizontal = false
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        guard canvas.drawing.dataRepresentation() != drawing.dataRepresentation() else { return }
        canvas.drawing = drawing
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        @Binding private var drawing: PKDrawing
        private let onDrawingChanged: () -> Void

        init(drawing: Binding<PKDrawing>, onDrawingChanged: @escaping () -> Void) {
            _drawing = drawing
            self.onDrawingChanged = onDrawingChanged
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            drawing = canvasView.drawing
            onDrawingChanged()
        }
    }
}

enum HandwritingScoreRecognizer {
    static func recognize(_ imageData: Data) async -> Int? {
        await Task.detached(priority: .userInitiated) {
            guard let image = UIImage(data: imageData)?.cgImage else { return nil }
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            request.recognitionLanguages = ["en-US"]

            do {
                try VNImageRequestHandler(cgImage: image).perform([request])
            } catch {
                return nil
            }

            let candidates = (request.results ?? []).flatMap { $0.topCandidates(3) }
            return candidates.compactMap { parse($0.string) }.first
        }.value
    }

    static func parse(_ text: String) -> Int? {
        let source = text
            .uppercased()
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "−", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var tokens: [String] = []
        var searchRange = source.startIndex..<source.endIndex
        while let range = source.range(of: #"-?[0-9OILS]+"#, options: .regularExpression, range: searchRange) {
            tokens.append(String(source[range]))
            searchRange = range.upperBound..<source.endIndex
        }

        let candidate = tokens
            .filter { token in
                token.contains(where: \.isNumber) || token == source
            }
            .max { $0.count < $1.count }

        guard let candidate else { return nil }
        let normalized = candidate
            .replacingOccurrences(of: "O", with: "0")
            .replacingOccurrences(of: "I", with: "1")
            .replacingOccurrences(of: "L", with: "1")
            .replacingOccurrences(of: "S", with: "5")
        return Int(normalized)
    }
}
