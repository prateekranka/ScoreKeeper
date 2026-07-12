import SwiftUI

struct AnimatedScoreChange: View {
    let delta: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDismissing = false

    var body: some View {
        if delta != 0 {
            Text(delta > 0 ? "+\(delta)" : "\(delta)")
                .font(.callout.bold())
                .monospacedDigit()
                .foregroundStyle(delta > 0 ? ClubhouseTheme.felt : ClubhouseTheme.lacquer)
                .opacity(isDismissing ? 0 : 1)
                .offset(y: isDismissing && !reduceMotion ? -6 : 0)
                .task {
                    try? await Task.sleep(for: .milliseconds(650))
                    guard !Task.isCancelled else { return }
                    withAnimation(AppMotion.fade) {
                        isDismissing = true
                    }
                }
        }
    }
}

struct ScoreChangeModifier: ViewModifier {
    let delta: Int
    @State private var showChange = false
    @State private var displayDelta = 0
    @State private var changeSequence = 0
    @State private var dismissalTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if showChange {
                    AnimatedScoreChange(delta: displayDelta)
                        .id(changeSequence)
                        .offset(y: -20)
                }
            }
            .onChange(of: delta) { oldValue, newValue in
                if newValue != oldValue {
                    dismissalTask?.cancel()
                    displayDelta = newValue - oldValue
                    changeSequence &+= 1
                    showChange = true
                    dismissalTask = Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(850))
                        guard !Task.isCancelled else { return }
                        withAnimation(AppMotion.fade) {
                            showChange = false
                        }
                    }
                }
            }
            .onDisappear {
                dismissalTask?.cancel()
            }
    }
}
