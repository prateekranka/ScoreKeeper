import PencilKit
import SwiftUI

struct ScoreWritingCanvas: UIViewRepresentable {
    @Binding var clearTrigger: Int
    @Binding var captureTrigger: Int
    @Binding var capturedImage: UIImage?
    @Binding var capturedPreviewImage: UIImage?
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
            let drawing = canvas.drawing
            let canvasSize = canvas.bounds.size
            let scale = max(Self.displayScale(for: canvas), 1)
            let captureID = captureTrigger
            let imageBinding = $capturedImage
            let previewImageBinding = $capturedPreviewImage
            let eventBinding = $captureEvent
            Task { @MainActor in
                // A replaced card can finish an older capture after a newer
                // one. Do not let that stale image overwrite the current
                // capture or move the event counter backwards.
                guard captureID > eventBinding.wrappedValue else { return }
                imageBinding.wrappedValue = Self.normalizedImage(
                    for: drawing,
                    canvasSize: canvasSize,
                    scale: scale
                )
                previewImageBinding.wrappedValue = Self.previewImage(
                    for: drawing,
                    canvasSize: canvasSize,
                    scale: scale
                )
                eventBinding.wrappedValue = captureID
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(lastCaptureTrigger: captureTrigger)
    }

    final class Coordinator {
        var lastClearTrigger = 0

        var lastCaptureTrigger: Int

        init(lastCaptureTrigger: Int) {
            self.lastCaptureTrigger = lastCaptureTrigger
        }
    }

    static func captureImage(from canvas: PKCanvasView) -> UIImage? {
        normalizedImage(
            for: canvas.drawing,
            canvasSize: canvas.bounds.size,
            scale: max(displayScale(for: canvas), 1)
        )
    }

    static func normalizedImage(for drawing: PKDrawing, canvasSize: CGSize, scale: CGFloat) -> UIImage? {
        guard canvasSize.width.isFinite, canvasSize.height.isFinite,
              canvasSize.width > 0, canvasSize.height > 0 else { return nil }
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

            // PKDrawing.image renders white ink with alpha. Remove the ink-shaped
            // pixels from an opaque white surface, then place black behind those
            // transparent holes. UIImage.draw preserves PencilKit's orientation.
            context.setFillColor(UIColor.white.cgColor)
            context.fill(canvasRect)
            context.saveGState()
            // PKDrawing.image's bitmap is vertically oriented for Core Graphics,
            // while UIImage drawing uses UIKit's top-left coordinate space. Flip
            // the source only while compositing so the captured score stays
            // upright for Vision and callers that inspect the raster.
            context.translateBy(x: fittedInkRect.minX, y: fittedInkRect.maxY)
            context.scaleBy(x: 1, y: -1)
            inkImage.draw(
                in: CGRect(origin: .zero, size: fittedInkRect.size),
                blendMode: .destinationOut,
                alpha: 1
            )
            context.restoreGState()
            context.setBlendMode(.destinationOver)
            context.setFillColor(UIColor.black.cgColor)
            context.fill(fittedInkRect)
        }
    }

    /// Cropped black-on-white thumbnail that matches the canvas orientation.
    static func previewImage(for drawing: PKDrawing, canvasSize: CGSize, scale: CGFloat) -> UIImage? {
        guard canvasSize.width.isFinite, canvasSize.height.isFinite,
              canvasSize.width > 0, canvasSize.height > 0 else { return nil }
        guard !drawing.strokes.isEmpty else { return nil }
        let inkBounds = drawing.bounds
        guard !inkBounds.isNull, inkBounds.width >= 0.5, inkBounds.height >= 0.5 else { return nil }
        let padding = max(min(canvasSize.width, canvasSize.height) * 0.05, 24)
        let canvasRect = CGRect(origin: .zero, size: canvasSize)
        let captureRect = inkBounds.insetBy(dx: -padding, dy: -padding).intersection(canvasRect)
        guard !captureRect.isNull, captureRect.width >= 0.5, captureRect.height >= 0.5 else { return nil }

        let renderScale = max(scale, 1)
        let inkImage = drawing.image(from: captureRect, scale: renderScale)
        guard inkImage.cgImage != nil else { return nil }

        let bakeFormat = UIGraphicsImageRendererFormat()
        bakeFormat.scale = renderScale
        bakeFormat.opaque = false
        let bakeRenderer = UIGraphicsImageRenderer(size: captureRect.size, format: bakeFormat)
        let uprightInk = bakeRenderer.image { _ in
            inkImage.draw(in: CGRect(origin: .zero, size: captureRect.size))
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = renderScale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: captureRect.size, format: format)
        return renderer.image { rendererContext in
            let context = rendererContext.cgContext
            let outputRect = CGRect(origin: .zero, size: captureRect.size)
            context.setFillColor(UIColor.white.cgColor)
            context.fill(outputRect)
            context.saveGState()
            context.translateBy(x: 0, y: outputRect.height)
            context.scaleBy(x: 1, y: -1)
            uprightInk.draw(in: outputRect, blendMode: .destinationOut, alpha: 1)
            context.restoreGState()
            context.setBlendMode(.destinationOver)
            context.setFillColor(UIColor.black.cgColor)
            context.fill(outputRect)
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
