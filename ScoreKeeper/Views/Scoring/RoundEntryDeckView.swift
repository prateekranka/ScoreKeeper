import PencilKit
import SwiftUI

private enum ScoreEntryState: Equatable {
    case drawing
    case recognizing(requestID: Int)
    case confirming(value: Int)
    case manual
    case noInk
}

struct RoundEntryDeckView: View {
    let session: GameSession
    let onSubmit: ([UUID: Int]) -> Void
    let onCancel: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var currentIndex = 0
    @State private var scores: [UUID: Int] = [:]
    @State private var clearTriggers: [UUID: Int] = [:]
    @State private var entryState: ScoreEntryState = .drawing
    @State private var manualEntry = ""
    @State private var showTutorial = !UserDefaults.standard.bool(forKey: "hasSeenScoreDeckTutorial")
    @State private var captureTrigger = 0
    @State private var captureEvent = 0
    @State private var capturedImage: UIImage?
    @State private var sourceImage: UIImage?
    @State private var isPresented = false
    @State private var isExiting = false
    @State private var feedbackTrigger = 0
    @State private var warningFeedbackTrigger = 0
    @State private var recognitionRequestID = 0

    private var player: Player {
        session.players[currentIndex]
    }

    private var isRecognizing: Bool {
        if case .recognizing(_) = entryState { return true }
        return false
    }

    private var canRecognize: Bool {
        switch entryState {
        case .drawing, .noInk:
            return true
        case .recognizing(_), .confirming(_), .manual:
            return false
        }
    }

    private var canClear: Bool {
        !isRecognizing && !isExiting
    }

    private var canSwitchPlayer: Bool {
        canClear
    }

    private var showsDrawingActions: Bool {
        canRecognize
    }

    var body: some View {
        GeometryReader { proxy in
            Group {
                if proxy.size.width >= 760 && !dynamicTypeSize.isAccessibilitySize {
                    tabletLayout
                } else {
                    phoneLayout
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .background(PipCountPaperBackground().ignoresSafeArea())
        .opacity(isPresented && !isExiting ? 1 : 0)
        .scaleEffect(isPresented && !isExiting ? 1 : 0.985)
        .offset(y: isPresented && !isExiting || reduceMotion ? 0 : 14)
        .animation(reduceMotion ? AppMotion.fade : AppMotion.artEntrance, value: isPresented)
        .animation(reduceMotion ? AppMotion.fade : AppMotion.artExit, value: isExiting)
        .overlay {
            if showTutorial {
                tutorial
                    .allowsHitTesting(showTutorial)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("round_entry_deck")
        .sensoryFeedback(.selection, trigger: feedbackTrigger)
        .sensoryFeedback(.warning, trigger: warningFeedbackTrigger)
        .onAppear {
            isPresented = true
        }
        .onDisappear {
            invalidateRecognition()
        }
        .onChange(of: captureEvent) { _, eventID in
            handleCaptureEvent(eventID)
        }
    }

    private var tabletLayout: some View {
        HStack(spacing: 0) {
            tabletSidebar
                .frame(minWidth: 310, idealWidth: 360, maxWidth: 410)

            Rectangle()
                .fill(ClubhouseTheme.rule)
                .frame(width: 1)
                .padding(.vertical, AppTheme.spacingLarge)

            playerCard
                .padding(AppTheme.spacingLarge)
        }
        .padding(.horizontal, AppTheme.spacingLarge)
        .padding(.vertical, AppTheme.spacingMedium)
    }

    private var tabletSidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.spacingLarge) {
                header

                VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
                    Text("Write it. Check it. Keep playing.")
                        .font(AppFonts.hero)
                        .foregroundStyle(ClubhouseTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Use your finger or Apple Pencil. PipCount reads the score, then asks you to confirm it before moving on.")
                        .font(AppFonts.body)
                        .foregroundStyle(ClubhouseTheme.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                PipCountGeometricArtwork(scene: .handwriting)
                    .frame(maxWidth: 340)
                    .frame(height: 292)

                playerProgressCard
            }
            .padding(.trailing, AppTheme.spacingLarge)
        }
        .scrollIndicators(.hidden)
    }

    private var phoneLayout: some View {
        VStack(spacing: AppTheme.spacingSmall) {
            header
                .padding(.horizontal, AppTheme.spacingMedium)

            HStack(alignment: .center, spacing: AppTheme.spacingSmall) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Draw the score")
                        .font(AppFonts.title)
                        .foregroundStyle(ClubhouseTheme.ink)
                }

                Spacer()

                PipCountGeometricArtwork(scene: .handwriting)
                    .frame(width: 104, height: 78)
            }
            .padding(.horizontal, AppTheme.spacingMedium)

            playerCard
                .padding(.horizontal, AppTheme.spacingMedium)
                .padding(.bottom, 4)
        }
        .padding(.top, AppTheme.spacingSmall)
    }

    private var header: some View {
        HStack(spacing: AppTheme.spacingSmall) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Round \(session.currentRoundNumber)")
                    .font(AppFonts.headline)
                    .foregroundStyle(ClubhouseTheme.ink)
                    .monospacedDigit()

                Text(session.gameType.displayName)
                    .font(AppFonts.caption)
                    .foregroundStyle(ClubhouseTheme.blue)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                performExit(onCancel)
            } label: {
                Image(systemName: "xmark")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(ClubhouseTheme.ink)
                    .frame(width: 44, height: 44)
                    .background(ClubhouseTheme.paperCard, in: Circle())
                    .overlay {
                        Circle()
                            .strokeBorder(ClubhouseTheme.rule, lineWidth: 1)
                    }
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("Cancel")
            .accessibilityIdentifier("round_deck_cancel_button")
        }
    }

    private var playerProgressCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingSmall) {
            Text("Tonight's scores")
                .columnHeaderStyle()

            ForEach(Array(session.players.enumerated()), id: \.element.id) { index, candidate in
                HStack(spacing: AppTheme.spacingSmall) {
                    BauhausPlayerShape(colorIndex: candidate.colorIndex, size: 22)

                    Text(candidate.name)
                        .font(AppFonts.body.weight(index == currentIndex ? .bold : .regular))
                        .foregroundStyle(ClubhouseTheme.ink)
                        .lineLimit(1)

                    Spacer()

                    if let score = scores[candidate.id] {
                        Text("\(score)")
                            .font(AppFonts.scoreSmall)
                            .monospacedDigit()
                            .foregroundStyle(ClubhouseTheme.blue)
                    } else if index == currentIndex {
                        Text("Writing")
                            .font(AppFonts.caption.weight(.bold))
                            .foregroundStyle(ClubhouseTheme.red)
                    } else {
                        Circle()
                            .strokeBorder(ClubhouseTheme.ruleStrong, lineWidth: 1)
                            .frame(width: 10, height: 10)
                    }
                }
                .padding(.vertical, 7)
                .contentShape(Rectangle())
                .onTapGesture {
                    guard index != currentIndex, canSwitchPlayer else { return }
                    switchPlayer(to: index)
                }
            }
        }
        .padding(AppTheme.spacingMedium)
        .scorecardSurface(cornerRadius: AppTheme.cornerRadiusLarge)
    }

    private var playerCard: some View {
        VStack(spacing: AppTheme.spacingMedium) {
            playerHeader

            writingSurface
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if case .noInk = entryState {
                noInkHint
            }

            if showsDrawingActions {
                scoreActions
            }
        }
        .padding(AppTheme.spacingMedium)
        .background(ClubhouseTheme.paperCard, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                .strokeBorder(ClubhouseTheme.ink.opacity(0.72), lineWidth: 1.5)
        }
        .shadow(color: ClubhouseTheme.paperShadow, radius: 18, y: 10)
        .animation(reduceMotion ? AppMotion.fade : AppMotion.state, value: entryState)
        .id(player.id)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .offset(x: 24)),
            removal: .opacity.combined(with: .offset(x: -24))
        ))
    }

    private var playerHeader: some View {
        HStack(spacing: AppTheme.spacingSmall) {
            BauhausPlayerShape(colorIndex: player.colorIndex, size: 48)

            VStack(alignment: .leading, spacing: 2) {
                Text(player.name)
                    .font(AppFonts.title)
                    .foregroundStyle(ClubhouseTheme.ink)
                    .lineLimit(1)

                Text("Running total \(player.totalScore(in: session))")
                    .font(AppFonts.caption)
                    .foregroundStyle(ClubhouseTheme.inkMuted)
                    .monospacedDigit()
            }

            Spacer()

            Text("\(currentIndex + 1) / \(session.players.count)")
                .font(AppFonts.columnHeader)
                .foregroundStyle(ClubhouseTheme.blue)
                .monospacedDigit()
        }
    }

    private var writingSurface: some View {
        ZStack {
            ScoreWritingCanvas(
                clearTrigger: clearBinding(for: player),
                captureTrigger: $captureTrigger,
                capturedImage: $capturedImage,
                captureEvent: $captureEvent
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))

            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                .strokeBorder(ClubhouseTheme.ink.opacity(0.72), lineWidth: 1.5)
                .allowsHitTesting(false)

            entryOverlay
        }
        .background(ClubhouseTheme.paperCard)
        .shadow(color: ClubhouseTheme.paperShadow, radius: 0, x: 4, y: 5)
        .contentShape(Rectangle())
        .overlay(alignment: .leading) {
            Color.clear
                .frame(width: 48)
                .contentShape(Rectangle())
                .gesture(edgeSwipe)
        }
        .overlay(alignment: .trailing) {
            Color.clear
                .frame(width: 48)
                .contentShape(Rectangle())
                .gesture(edgeSwipe)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Drawing area for \(player.name)'s score")
    }

    private var scoreActions: some View {
        HStack(spacing: AppTheme.spacingSmall) {
            Text("Tap the blue check when finished")
                .font(AppFonts.caption)
                .foregroundStyle(ClubhouseTheme.inkMuted)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                clear(for: player)
            } label: {
                Image(systemName: "delete.left")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(ClubhouseTheme.ink)
                    .frame(width: 48, height: 48)
                    .background(ClubhouseTheme.paperSunken, in: Circle())
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(!canClear)
            .accessibilityLabel("Clear score")
            .accessibilityIdentifier("deck_clear_\(player.name)")

            Button {
                recognizeCurrent()
            } label: {
                Image(systemName: "checkmark")
                    .font(.title3.weight(.black))
                    .foregroundStyle(ClubhouseTheme.onPrimary)
                    .frame(width: 52, height: 52)
                    .background(ClubhouseTheme.blue, in: Circle())
                    .shadow(color: ClubhouseTheme.blue.opacity(0.22), radius: 8, y: 5)
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(!canRecognize)
            .accessibilityLabel("Recognize score")
            .accessibilityIdentifier("recognize_score_button")
        }
    }

    @ViewBuilder
    private var entryOverlay: some View {
        switch entryState {
        case .drawing, .noInk:
            EmptyView()
        case .recognizing(_):
            recognizingOverlay
                .transition(.opacity)
        case .confirming(let value):
            confirmation(value: value, image: sourceImage)
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
        case .manual:
            rejectionCard
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
        }
    }

    private var recognizingOverlay: some View {
        VStack(spacing: AppTheme.spacingSmall) {
            ProgressView()
                .controlSize(.large)
                .tint(ClubhouseTheme.blue)

            Text("Reading your score…")
                .font(AppFonts.headline)
                .foregroundStyle(ClubhouseTheme.ink)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ClubhouseTheme.paper.opacity(0.94))
        .accessibilityLabel("Reading score")
    }

    private var noInkHint: some View {
        Text("Draw the score first")
            .font(AppFonts.caption.weight(.semibold))
            .foregroundStyle(ClubhouseTheme.inkMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .transition(.opacity)
            .accessibilityIdentifier("deck_no_ink_hint")
    }

    private func confirmation(value: Int, image: UIImage?) -> some View {
        VStack(spacing: AppTheme.spacingLarge) {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 220, maxHeight: 108)
                    .padding(8)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                            .strokeBorder(ClubhouseTheme.ruleStrong, lineWidth: 1)
                    }
                    .accessibilityLabel("Source drawing")
                    .accessibilityIdentifier("deck_source_thumbnail")
            }

            VStack(spacing: 4) {
                Text("\(value)")
                    .font(AppFonts.scoreDisplay)
                    .monospacedDigit()
                    .foregroundStyle(ClubhouseTheme.ink)
                    .contentTransition(.numericText(value: Double(value)))

                Text("Is this right?")
                    .font(AppFonts.headline)
                    .foregroundStyle(ClubhouseTheme.ink)
            }

            HStack(spacing: AppTheme.spacingSmall) {
                Button {
                    redraw()
                } label: {
                    Label("Redraw", systemImage: "arrow.counterclockwise")
                        .font(AppFonts.headline)
                        .foregroundStyle(ClubhouseTheme.blue)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, AppTheme.spacingSmall)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(ClubhouseTheme.paperCard, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                                .strokeBorder(ClubhouseTheme.ruleStrong, lineWidth: 1)
                        }
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel("Redraw score")
                .accessibilityIdentifier("deck_retry_\(player.name)")

                Button {
                    accept(value)
                } label: {
                    Label("Use \(value)", systemImage: "checkmark")
                        .font(AppFonts.headline)
                        .foregroundStyle(ClubhouseTheme.onPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, AppTheme.spacingSmall)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(ClubhouseTheme.blue, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel("Use \(value)")
                .accessibilityIdentifier("deck_accept_\(player.name)")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ClubhouseTheme.paper.opacity(0.97))
    }

    private var rejectionCard: some View {
        VStack(spacing: AppTheme.spacingLarge) {
            VStack(spacing: 4) {
                Text("Couldn't read that")
                    .font(AppFonts.headline)
                    .foregroundStyle(ClubhouseTheme.ink)
                    .accessibilityIdentifier("deck_invalid_value")

                Text("Redraw or type the score.")
                    .font(AppFonts.caption)
                    .foregroundStyle(ClubhouseTheme.inkMuted)
            }

            HStack(spacing: AppTheme.spacingSmall) {
                Button {
                    redraw()
                } label: {
                    Label("Redraw", systemImage: "arrow.counterclockwise")
                        .font(AppFonts.headline)
                        .foregroundStyle(ClubhouseTheme.blue)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, AppTheme.spacingSmall)
                        .frame(minHeight: 56)
                        .background(ClubhouseTheme.paperCard, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                                .strokeBorder(ClubhouseTheme.ruleStrong, lineWidth: 1)
                        }
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel("Redraw score")
                .accessibilityIdentifier("deck_retry_\(player.name)")

                TextField("Score", text: $manualEntry)
                    .keyboardType(.numberPad)
                    .font(AppFonts.scoreSmall)
                    .monospacedDigit()
                    .multilineTextAlignment(.center)
                    .foregroundStyle(ClubhouseTheme.ink)
                    .frame(width: 72, height: 56)
                    .background(ClubhouseTheme.paperSunken, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous)
                            .strokeBorder(ClubhouseTheme.rule, lineWidth: 1)
                    }
                    .accessibilityLabel("Enter score manually")
                    .accessibilityIdentifier("deck_manual_value")

                Button {
                    guard let manualScore else { return }
                    accept(manualScore)
                } label: {
                    Text(manualScore.map { "Use \($0)" } ?? "Use")
                        .font(AppFonts.headline)
                        .foregroundStyle(ClubhouseTheme.onPrimary)
                        .padding(.horizontal, AppTheme.spacingMedium)
                        .frame(height: 56)
                        .background(ClubhouseTheme.blue, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall, style: .continuous))
                }
                .buttonStyle(PressableButtonStyle())
                .disabled(manualScore == nil || isExiting)
                .opacity(manualScore == nil || isExiting ? 0.45 : 1)
                .accessibilityLabel(manualScore.map { "Use \($0)" } ?? "Enter a valid score")
                .accessibilityIdentifier("deck_manual_use_\(player.name)")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ClubhouseTheme.paper.opacity(0.97))
    }

    private var manualScore: Int? {
        guard !manualEntry.isEmpty,
              manualEntry.count <= 2,
              manualEntry.allSatisfy({ ("0"..."9").contains($0) }),
              let value = Int(manualEntry),
              (0...99).contains(value)
        else {
            return nil
        }
        return value
    }

    private var tutorial: some View {
        ZStack {
            ClubhouseTheme.ink.opacity(0.22)
                .ignoresSafeArea()
                .onTapGesture { dismissTutorial() }

            VStack(spacing: AppTheme.spacingLarge) {
                PipCountGeometricArtwork(scene: .handwriting)
                    .frame(width: 230, height: 190)

                VStack(spacing: AppTheme.spacingSmall) {
                    Text("Score with your finger")
                        .font(AppFonts.title)
                        .foregroundStyle(ClubhouseTheme.ink)

                    Text("Draw each player's score, tap ✓ to read it, then confirm. Swipe from either edge to move between players.")
                        .font(AppFonts.body)
                        .foregroundStyle(ClubhouseTheme.inkMuted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                AppActionButton(role: .primary(ClubhouseTheme.blue), action: dismissTutorial) {
                    Text("Got it")
                }

                Button("Skip", action: dismissTutorial)
                    .font(AppFonts.caption.weight(.semibold))
                    .foregroundStyle(ClubhouseTheme.ink)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .padding(AppTheme.spacingLarge)
            .frame(maxWidth: 430)
            .background(ClubhouseTheme.paperCard, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                    .strokeBorder(ClubhouseTheme.ink.opacity(0.62), lineWidth: 1.5)
            }
            .shadow(color: ClubhouseTheme.paperShadow, radius: 28, y: 16)
            .padding(AppTheme.spacingLarge)
        }
        .accessibilityElement(children: .contain)
    }

    private func dismissTutorial() {
        withAnimation(reduceMotion ? AppMotion.fade : AppMotion.state) {
            showTutorial = false
        }
        UserDefaults.standard.set(true, forKey: "hasSeenScoreDeckTutorial")
    }

    private func clearBinding(for player: Player) -> Binding<Int> {
        Binding(
            get: { clearTriggers[player.id, default: 0] },
            set: { clearTriggers[player.id] = $0 }
        )
    }

    private func handleCaptureEvent(_ eventID: Int) {
        guard !isExiting,
              case .recognizing(let activeRequestID) = entryState,
              activeRequestID == eventID,
              eventID == recognitionRequestID
        else { return }

        guard let image = capturedImage else {
            entryState = .noInk
            warningFeedbackTrigger &+= 1
            return
        }

        let targetPlayerID = player.id
        let targetIndex = currentIndex
        let requestID = eventID

        Task { @MainActor in
            let result = await ScoreRecognizer.recognize(image)

            guard !isExiting,
                  requestID == recognitionRequestID,
                  targetPlayerID == player.id,
                  targetIndex == currentIndex,
                  case .recognizing(let activeRequestID) = entryState,
                  activeRequestID == requestID
            else { return }

            switch result {
            case .success(let value, _):
                sourceImage = image
                entryState = .confirming(value: value)
                feedbackTrigger &+= 1
            case .noInk:
                entryState = .noInk
                warningFeedbackTrigger &+= 1
            case .unreadable, .error:
                sourceImage = nil
                manualEntry = ""
                entryState = .manual
                warningFeedbackTrigger &+= 1
            }
        }
    }

    private func invalidateRecognition() {
        recognitionRequestID &+= 1
        if isRecognizing {
            entryState = .drawing
        }
    }

    private func clear(for player: Player) {
        guard !isExiting else { return }
        invalidateRecognition()
        clearTriggers[player.id, default: 0] += 1
        scores[player.id] = nil
        capturedImage = nil
        sourceImage = nil
        manualEntry = ""
        entryState = .drawing
    }

    private func recognizeCurrent() {
        guard canRecognize, !isExiting else { return }

        recognitionRequestID &+= 1
        let requestID = recognitionRequestID
        capturedImage = nil
        sourceImage = nil
        manualEntry = ""
        entryState = .recognizing(requestID: requestID)
        captureTrigger = requestID
    }

    private func redraw() {
        guard !isExiting else { return }
        recognitionRequestID &+= 1
        clearTriggers[player.id, default: 0] += 1
        capturedImage = nil
        sourceImage = nil
        manualEntry = ""
        entryState = .drawing
    }

    private func accept(_ value: Int) {
        switch entryState {
        case .confirming(let confirmedValue):
            guard confirmedValue == value else { return }
        case .manual:
            guard let manualScore, manualScore == value else { return }
        case .drawing, .recognizing(_), .noInk:
            return
        }

        scores[player.id] = value
        recognitionRequestID &+= 1
        capturedImage = nil
        sourceImage = nil
        manualEntry = ""
        entryState = .drawing
        feedbackTrigger &+= 1

        if currentIndex == session.players.count - 1 {
            performExit {
                onSubmit(scores)
            }
        } else {
            switchPlayer(to: currentIndex + 1)
        }
    }

    private func switchPlayer(to index: Int) {
        guard session.players.indices.contains(index),
              index != currentIndex,
              !isExiting
        else { return }

        invalidateRecognition()
        capturedImage = nil
        sourceImage = nil
        manualEntry = ""
        entryState = .drawing

        if reduceMotion {
            currentIndex = index
        } else {
            withAnimation(AppMotion.page) {
                currentIndex = index
            }
        }
    }

    private var edgeSwipe: some Gesture {
        DragGesture(minimumDistance: 44)
            .onEnded { value in
                guard canSwitchPlayer else { return }
                guard abs(value.translation.width) > abs(value.translation.height) * 1.4 else { return }

                if value.translation.width < 0, currentIndex < session.players.count - 1 {
                    switchPlayer(to: currentIndex + 1)
                } else if value.translation.width > 0, currentIndex > 0 {
                    switchPlayer(to: currentIndex - 1)
                }
            }
    }

    private func performExit(_ completion: @escaping () -> Void) {
        guard !isExiting else { return }
        invalidateRecognition()

        if reduceMotion {
            completion()
            return
        }

        // Animate the deck out, but tear down the presenting cover FIRST.
        // Dismissing from inside a deferred Task used to leave an empty
        // full-screen presentation window installed above the app, which then
        // swallowed every subsequent touch on the underlying screen.
        isExiting = true
        completion()
    }
}
