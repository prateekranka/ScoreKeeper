import SwiftUI

struct ConfettiPiece: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    let color: Color
    let size: CGFloat
    let rotation: Double
    let speed: CGFloat
    let wobble: CGFloat
}

struct ConfettiOverlay: View {
    @State private var pieces: [ConfettiPiece] = []
    @State private var animationProgress: CGFloat = 0
    let colors: [Color] = PlayerColors.palette + [ClubhouseTheme.paperCard, ClubhouseTheme.brass, ClubhouseTheme.lacquer]

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                for piece in pieces {
                    let elapsed = animationProgress
                    let adjustedY = piece.y + piece.speed * elapsed * size.height
                    let adjustedX = piece.x * size.width + sin(elapsed * 3 + piece.wobble) * 30

                    guard adjustedY < size.height + 20 else { continue }

                    let rect = CGRect(
                        x: adjustedX - piece.size / 2,
                        y: adjustedY - piece.size / 2,
                        width: piece.size,
                        height: piece.size * 0.6
                    )

                    context.opacity = max(0, 1 - Double(elapsed) * 0.5)
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(piece.color)
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            generatePieces()
            withAnimation(.linear(duration: 3)) {
                animationProgress = 1
            }
        }
    }

    private func generatePieces() {
        pieces = (0..<80).map { _ in
            ConfettiPiece(
                x: CGFloat.random(in: 0...1),
                y: CGFloat.random(in: -200...(-20)),
                color: colors.randomElement() ?? .white,
                size: CGFloat.random(in: 6...12),
                rotation: Double.random(in: 0...360),
                speed: CGFloat.random(in: 0.3...1.0),
                wobble: CGFloat.random(in: 0...6)
            )
        }
    }
}
