import PencilKit
import SwiftUI

struct ScoreWritingCanvas: UIViewRepresentable {
    @Binding var clearTrigger: Int
    @Binding var captureTrigger: Int
    @Binding var capturedImage: UIImage?
    var accessibilityIdentifier: String = "score_writing_canvas"

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.backgroundColor = .white
        canvas.isOpaque = true
        canvas.drawingPolicy = .anyInput
        canvas.tool = PKInkingTool(.pen, color: .black, width: 8)
        canvas.accessibilityIdentifier = accessibilityIdentifier
        canvas.accessibilityLabel = "Draw score"
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        if context.coordinator.lastClearTrigger != clearTrigger {
            canvas.drawing = PKDrawing()
            context.coordinator.lastClearTrigger = clearTrigger
        }
        if context.coordinator.lastCaptureTrigger != captureTrigger {
            context.coordinator.lastCaptureTrigger = captureTrigger
            // Capture OUTSIDE the view-update transaction: assigning a state
            // binding synchronously inside updateUIView gets coalesced by
            // SwiftUI and onChange(of:) never observes the new value, leaving
            // recognition stuck on its progress overlay.
            let targetBounds = canvas.bounds
            let scale = max(Self.displayScale(for: canvas), 1)
            let imageBinding = $capturedImage
            Task { @MainActor in
                imageBinding.wrappedValue = canvas.drawing.image(from: targetBounds, scale: scale)
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var lastClearTrigger = 0
        var lastCaptureTrigger = 0
    }

    static func captureImage(from canvas: PKCanvasView) -> UIImage? {
        normalizedImage(
            for: canvas.drawing,
            canvasSize: canvas.bounds.size,
            scale: max(displayScale(for: canvas), 1)
        )
    }

    static func normalizedImage(for drawing: PKDrawing, canvasSize: CGSize, scale: CGFloat) -> UIImage? {
        guard !drawing.strokes.isEmpty else { return nil }
        let inkBounds = drawing.bounds
        guard !inkBounds.isNull, inkBounds.width >= 0.5, inkBounds.height >= 0.5 else { return nil }
        let padding = max(min(canvasSize.width, canvasSize.height) * 0.05, 24)
        let canvasRect = CGRect(origin: .zero, size: canvasSize)
        let captureRect = inkBounds.insetBy(dx: -padding, dy: -padding).intersection(canvasRect)
        guard !captureRect.isNull, captureRect.width >= 0.5, captureRect.height >= 0.5 else { return nil }
        let renderScale = max(scale, 1)
        let format = UIGraphicsImageRendererFormat()
        format.scale = renderScale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: captureRect.size, format: format)
        return renderer.image { _ in
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: captureRect.size))
            drawing.image(from: captureRect, scale: renderScale).draw(at: .zero)
        }
    }

    private static func displayScale(for canvas: PKCanvasView) -> CGFloat {
        let contextualScale = canvas.window?.windowScene?.screen.scale
            ?? canvas.traitCollection.displayScale
        return max(contextualScale, 1)
    }

    private func displayScale(for canvas: PKCanvasView) -> CGFloat {
        Self.displayScale(for: canvas)
    }
}
