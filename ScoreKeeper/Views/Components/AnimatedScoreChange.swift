import SwiftUI

struct AnimatedScoreChange: View {
    let delta: Int
    @State private var isVisible = true

    var body: some View {
        if isVisible && delta != 0 {
            Text(delta > 0 ? "+\(delta)" : "\(delta)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(delta > 0 ? .green : .red)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onAppear {
                    withAnimation(.easeOut(duration: 1.5).delay(0.5)) {
                        isVisible = false
                    }
                }
        }
    }
}

struct ScoreChangeModifier: ViewModifier {
    let delta: Int
    @State private var showChange = false
    @State private var displayDelta = 0

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if showChange {
                    AnimatedScoreChange(delta: displayDelta)
                        .offset(y: -20)
                }
            }
            .onChange(of: delta) { oldValue, newValue in
                if newValue != oldValue {
                    displayDelta = newValue - oldValue
                    showChange = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showChange = false
                    }
                }
            }
    }
}
