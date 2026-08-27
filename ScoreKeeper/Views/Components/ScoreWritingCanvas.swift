import PencilKit
import SwiftUI

struct ScoreWritingCanvas: UIViewRepresentable {
    @Binding var clearTrigger: Int
    @Binding var captureTrigger: Int
    @Binding var capturedImage: UIImage?
    @Binding var captureEvent: Int
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
            let canvasSize = canvas.bounds.size
            let scale = max(Self.displayScale(for: canvas), 1)
            let imageBinding = $capturedImage
            let eventBinding = $captureEvent
            Task { @MainActor in
                imageBinding.wrappedValue = Self.normalizedImage(
                    for: canvas.drawing,
                    canvasSize: canvasSize,
                    scale: scale
                )
                eventBinding.wrappedValue += 1
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
        let inkImage = drawing.image(from: inkBounds, scale: renderScale)
        guard inkImage.cgImage != nil else { return nil }

        // Vision is more reliable when a tightly cropped digit is presented on a
        // predictable, landscape recognition canvas. Preserve the padded crop's
        // aspect ratio, fit it into the target, and upscale small handwriting.
        let recognitionSize = CGSize(width: 512, height: 256)
        let recognitionContentRect = CGRect(
            x: 16,
            y: 16,
            width: recognitionSize.width - 32,
            height: recognitionSize.height - 32
        )
        let fitScale = min(
            recognitionContentRect.width / captureRect.width,
            recognitionContentRect.height / captureRect.height
        )
        guard fitScale.isFinite, fitScale > 0 else { return nil }
        let fittedCaptureSize = CGSize(
            width: captureRect.width * fitScale,
            height: captureRect.height * fitScale
        )
        let fittedCaptureOrigin = CGPoint(
            x: recognitionContentRect.midX - fittedCaptureSize.width / 2,
            y: recognitionContentRect.midY - fittedCaptureSize.height / 2
        )
        let fittedInkRect = CGRect(
            x: fittedCaptureOrigin.x + (inkBounds.minX - captureRect.minX) * fitScale,
            y: fittedCaptureOrigin.y + (inkBounds.minY - captureRect.minY) * fitScale,
            width: inkImage.size.width * fitScale,
            height: inkImage.size.height * fitScale
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = renderScale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: recognitionSize, format: format)
        return renderer.image { rendererContext in
            let context = rendererContext.cgContext
            let canvasRect = CGRect(origin: .zero, size: recognitionSize)

            // PKDrawing.image renders white ink with alpha. Draw it into a
            // transparent bitmap first, then use that alpha as a mask for black
            // ink on an opaque white surface. UIImage.draw preserves orientation.
            let maskFormat = UIGraphicsImageRendererFormat()
            maskFormat.scale = renderScale
            maskFormat.opaque = false
            let maskRenderer = UIGraphicsImageRenderer(size: recognitionSize, format: maskFormat)
            let maskImage = maskRenderer.image { _ in
                inkImage.draw(in: fittedInkRect)
            }
            context.setFillColor(UIColor.white.cgColor)
            context.fill(canvasRect)
            context.saveGState()
            context.clip(to: canvasRect, mask: maskImage.cgImage!)
            context.setFillColor(UIColor.black.cgColor)
            context.fill(canvasRect)
            context.restoreGState()
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
