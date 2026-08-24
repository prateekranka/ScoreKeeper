import PencilKit
import SwiftUI

struct RoundEntryDeckView: View {
    let session: GameSession
    let onSubmit: ([UUID: Int]) -> Void
    let onCancel: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var currentIndex = 0
    @State private var scores: [UUID: Int] = [:]
    @State private var clearTriggers: [UUID: Int] = [:]
    @State private var confirmingPlayer: UUID?
    @State private var confirmedValue: Int?
    @State private var showTutorial = !UserDefaults.standard.bool(forKey: "hasSeenScoreDeckTutorial")
    @State private var dragOffset: CGFloat = 0
    @State private var captureTrigger = 0
    @State private var capturedImage: UIImage?

    private var player: Player { session.players[currentIndex] }

    var body: some View {
        ZStack {
            ClubhouseTheme.paper.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                card
                progress
            }
            if showTutorial { tutorial }
        }
        .accessibilityIdentifier("round_entry_deck")
    }

    private var header: some View {
        HStack {
            Text("Round \(session.currentRoundNumber)")
                .font(AppFonts.headline)
                .foregroundStyle(ClubhouseTheme.ink)
            Spacer()
            Button { onCancel() } label: {
                Image(systemName: "xmark")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(ClubhouseTheme.ink)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Cancel")
            .accessibilityIdentifier("round_deck_cancel_button")
        }
        .padding(.horizontal, AppTheme.spacingMedium)
        .padding(.top, AppTheme.spacingSmall)
    }

    private var card: some View {
        VStack(spacing: AppTheme.spacingMedium) {
            HStack(spacing: AppTheme.spacingSmall) {
                BauhausPlayerShape(colorIndex: player.colorIndex, size: 46)
                VStack(alignment: .leading, spacing: 2) {
                    Text(player.name).font(AppFonts.title).foregroundStyle(ClubhouseTheme.ink)
                    Text("Total \(player.totalScore(in: session))")
                        .font(AppFonts.caption).foregroundStyle(ClubhouseTheme.inkMuted).monospacedDigit()
                }
                Spacer()
                Text("\(currentIndex + 1) / \(session.players.count)")
                    .font(AppFonts.columnHeader).foregroundStyle(ClubhouseTheme.blue)
            }

            ZStack {
                ScoreWritingCanvas(clearTrigger: clearBinding(for: player), captureTrigger: $captureTrigger, capturedImage: $capturedImage)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
                    .overlay { RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium).strokeBorder(ClubhouseTheme.ink, lineWidth: 1.5) }
                if confirmingPlayer == player.id, let confirmedValue {
                    confirmation(value: confirmedValue)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ClubhouseTheme.paperCard)
            .shadow(color: ClubhouseTheme.paperShadow, radius: 0, x: 4, y: 5)
            .contentShape(Rectangle())
            .overlay(alignment: .leading) { Color.clear.frame(width: 56).contentShape(Rectangle()).gesture(edgeSwipe) }
            .overlay(alignment: .trailing) { Color.clear.frame(width: 56).contentShape(Rectangle()).gesture(edgeSwipe) }

            HStack(spacing: AppTheme.spacingSmall) {
                Text(scores[player.id].map(String.init) ?? "Draw your score")
                    .font(AppFonts.scoreMedium).monospacedDigit().foregroundStyle(ClubhouseTheme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button { clear(for: player) } label: { Image(systemName: "delete.left").font(.title2) }
                    .accessibilityLabel("Clear score")
                Button { recognizeCurrent() } label: { Image(systemName: "checkmark.circle.fill").font(.title).foregroundStyle(ClubhouseTheme.blue) }
                    .accessibilityLabel("Recognize score")
                    .accessibilityIdentifier("recognize_score_button")
            }
            .foregroundStyle(ClubhouseTheme.ink)
            .padding(.horizontal, AppTheme.spacingSmall)
        }
        .padding(AppTheme.spacingMedium)
        .background(ClubhouseTheme.paperCard)
        .overlay { Rectangle().strokeBorder(ClubhouseTheme.ink, lineWidth: 1.5) }
        .padding(.horizontal, AppTheme.spacingMedium)
        .offset(x: dragOffset)
        .animation(reduceMotion ? nil : .spring(response: 0.28), value: currentIndex)
    }

    private var progress: some View {
        HStack(spacing: 8) {
            ForEach(session.players.indices, id: \.self) { index in
                Circle().fill(index == currentIndex ? ClubhouseTheme.blue : ClubhouseTheme.ink.opacity(0.25)).frame(width: 8, height: 8)
                    .accessibilityHidden(true)
            }
        }.padding(.vertical, AppTheme.spacingMedium)
    }

    private func confirmation(value: Int) -> some View {
        VStack(spacing: AppTheme.spacingMedium) {
            Text("\(value)").font(AppFonts.scoreDisplay).monospacedDigit().foregroundStyle(ClubhouseTheme.ink)
            Text("Is this right?").font(AppFonts.headline).foregroundStyle(ClubhouseTheme.ink)
            HStack(spacing: 28) {
                Button { retry() } label: { Image(systemName: "arrow.counterclockwise").font(.title).frame(width: 58, height: 58) }
                    .accessibilityLabel("Retry")
                Button { accept(value) } label: { Image(systemName: "checkmark").font(.title.bold()).frame(width: 58, height: 58) }
                    .accessibilityLabel("Accept")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ClubhouseTheme.paper.opacity(0.97))
    }

    private var tutorial: some View {
        VStack(spacing: AppTheme.spacingMedium) {
            Text("Score with your finger").font(AppFonts.title)
            Text("Draw each player's score. Tap ✓ to check the number. Swipe at the card edge to move between players.").font(AppFonts.body).multilineTextAlignment(.center)
            Button("Got it") { showTutorial = false; UserDefaults.standard.set(true, forKey: "hasSeenScoreDeckTutorial") }
                .buttonStyle(.borderedProminent)
            Button("Skip") { showTutorial = false; UserDefaults.standard.set(true, forKey: "hasSeenScoreDeckTutorial") }.font(AppFonts.caption)
        }
        .padding(AppTheme.spacingLarge)
        .background(ClubhouseTheme.paperCard)
        .overlay { Rectangle().strokeBorder(ClubhouseTheme.ink, lineWidth: 1.5) }
        .padding(AppTheme.spacingLarge)
        .shadow(color: ClubhouseTheme.paperShadow, radius: 0, x: 4, y: 5)
    }

    private func clearBinding(for player: Player) -> Binding<Int> {
        Binding(get: { clearTriggers[player.id, default: 0] }, set: { clearTriggers[player.id] = $0 })
    }
    private func clear(for player: Player) { clearTriggers[player.id, default: 0] += 1; scores[player.id] = nil; confirmingPlayer = nil; confirmedValue = nil }
    private func recognizeCurrent() {
        captureTrigger &+= 1
        guard let capturedImage else { return }
        Task { @MainActor in
            let value = await ScoreRecognizer.recognize(capturedImage)
            guard let value else { return }
            confirmingPlayer = player.id
            confirmedValue = value
        }
    }
    private func retry() { clear(for: player) }
    private func accept(_ value: Int) {
        scores[player.id] = value
        confirmingPlayer = nil
        confirmedValue = nil
        if currentIndex == session.players.count - 1 { onSubmit(scores) } else { currentIndex += 1 }
    }
    private var edgeSwipe: some Gesture {
        DragGesture(minimumDistance: 60).onEnded { value in
            guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
            if value.translation.width < 0, currentIndex < session.players.count - 1 { currentIndex += 1 }
            if value.translation.width > 0, currentIndex > 0 { currentIndex -= 1 }
        }
    }
}
