import PencilKit
import XCTest
@testable import ScoreKeeper

final class ScoreWritingCanvasTests: XCTestCase {
    func testEmptyDrawingReturnsNil() {
        XCTAssertNil(ScoreWritingCanvas.normalizedImage(
            for: PKDrawing(), canvasSize: CGSize(width: 320, height: 160), scale: 2
        ))
    }

    func testInvalidZeroSizeCanvasReturnsNil() {
        XCTAssertNil(ScoreWritingCanvas.normalizedImage(
            for: drawing([[CGPoint(x: 40, y: 40), CGPoint(x: 80, y: 80)]]),
            canvasSize: .zero,
            scale: 2
        ))
    }

    func testNormalizedOutputPreservesRequestedPixelScale() throws {
        let drawing = drawing([[CGPoint(x: 40, y: 40), CGPoint(x: 180, y: 100)]])
        for scale in [CGFloat(1), 2, 3] {
            let image = try XCTUnwrap(ScoreWritingCanvas.normalizedImage(
                for: drawing, canvasSize: CGSize(width: 320, height: 160), scale: scale
            ))
            let expectedScale = max(scale, 1)
            XCTAssertEqual(image.cgImage?.width, Int(512 * expectedScale))
            XCTAssertEqual(image.cgImage?.height, Int(256 * expectedScale))
        }
    }

    func testOutputHasOpaqueWhiteBackgroundAndDarkInk() throws {
        let image = try XCTUnwrap(ScoreWritingCanvas.normalizedImage(
            for: drawing([[CGPoint(x: 80, y: 70), CGPoint(x: 240, y: 70)]]),
            canvasSize: CGSize(width: 320, height: 160), scale: 2
        ))
        let cgImage = try XCTUnwrap(image.cgImage)
        let raster = PixelRaster(cgImage)
        let background = raster.pixel(x: 0, y: 0)
        XCTAssertEqual(background.0, 255)
        XCTAssertEqual(background.1, 255)
        XCTAssertEqual(background.2, 255)
        XCTAssertEqual(background.3, 255)
        XCTAssertTrue(raster.hasDarkPixel(in: CGRect(x: 0, y: cgImage.height / 2, width: cgImage.width, height: 1)))
    }

    func testPreviewImageMatchesCanvasLeftRightAndTop() throws {
        let image = try XCTUnwrap(ScoreWritingCanvas.previewImage(
            for: drawing([[CGPoint(x: 60, y: 40), CGPoint(x: 220, y: 40), CGPoint(x: 220, y: 120)]]),
            canvasSize: CGSize(width: 320, height: 160),
            scale: 2
        ))
        let cgImage = try XCTUnwrap(image.cgImage)
        let raster = PixelRaster(cgImage)
        let topInk = raster.darkPixelCount(in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height / 2))
        let bottomInk = raster.darkPixelCount(in: CGRect(
            x: 0,
            y: cgImage.height / 2,
            width: cgImage.width,
            height: cgImage.height / 2
        ))
        let leftInk = raster.darkPixelCount(in: CGRect(x: 0, y: 0, width: cgImage.width / 2, height: cgImage.height))
        let rightInk = raster.darkPixelCount(in: CGRect(
            x: cgImage.width / 2,
            y: 0,
            width: cgImage.width / 2,
            height: cgImage.height
        ))
        XCTAssertGreaterThan(topInk, bottomInk)
        XCTAssertGreaterThan(rightInk, leftInk)
        XCTAssertTrue(raster.hasDarkPixel(in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height)))
    }

    func testInkTouchingEveryCanvasEdgeRemainsRepresented() throws {
        let image = try XCTUnwrap(ScoreWritingCanvas.normalizedImage(
            for: drawing([
                [CGPoint(x: 0, y: 80), CGPoint(x: 320, y: 80)],
                [CGPoint(x: 160, y: 0), CGPoint(x: 160, y: 160)]
            ]),
            canvasSize: CGSize(width: 320, height: 160), scale: 2
        ))
        let cgImage = try XCTUnwrap(image.cgImage)
        let raster = PixelRaster(cgImage)
        let pixelScale = CGFloat(cgImage.width) / 512
        let edgeBand = 35 * pixelScale
        let crossbarBand = 96 * pixelScale
        XCTAssertTrue(raster.hasDarkPixel(in: CGRect(
            x: 0,
            y: 80 * pixelScale,
            width: edgeBand,
            height: crossbarBand
        )))
        XCTAssertTrue(raster.hasDarkPixel(in: CGRect(
            x: CGFloat(cgImage.width) - edgeBand,
            y: 80 * pixelScale,
            width: edgeBand,
            height: crossbarBand
        )))
        XCTAssertTrue(raster.hasDarkPixel(in: CGRect(
            x: 208 * pixelScale,
            y: 0,
            width: crossbarBand,
            height: edgeBand
        )))
        XCTAssertTrue(raster.hasDarkPixel(in: CGRect(
            x: 208 * pixelScale,
            y: CGFloat(cgImage.height) - edgeBand,
            width: crossbarBand,
            height: edgeBand
        )))
    }

    private func drawing(_ strokes: [[CGPoint]], width: CGFloat = 10) -> PKDrawing {
        let ink = PKInkingTool(.pen, color: .black, width: width).ink
        return PKDrawing(strokes: strokes.map { points in
            let path = PKStrokePath(controlPoints: points.enumerated().map { index, point in
                PKStrokePoint(location: point, timeOffset: Double(index) * 0.01,
                              size: CGSize(width: width, height: width), opacity: 1,
                              force: 1, azimuth: 0, altitude: .pi / 2)
            }, creationDate: Date(timeIntervalSinceReferenceDate: 0))
            return PKStroke(ink: ink, path: path, transform: .identity, mask: nil)
        })
    }

}

private struct PixelRaster {
    let bytes: [UInt8]
    let width: Int
    let height: Int

    init(_ image: CGImage) {
        let pixelWidth = image.width
        let pixelHeight = image.height
        var renderedBytes = [UInt8](repeating: 0, count: pixelWidth * pixelHeight * 4)
        let rendered = renderedBytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: pixelWidth,
                height: pixelHeight,
                bitsPerComponent: 8,
                bytesPerRow: pixelWidth * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue
                    | CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }

            context.translateBy(x: 0, y: CGFloat(pixelHeight))
            context.scaleBy(x: 1, y: -1)
            context.draw(image, in: CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
            return true
        }
        precondition(rendered)
        width = pixelWidth
        height = pixelHeight
        bytes = renderedBytes
    }

    func pixel(x: Int, y: Int) -> (UInt8, UInt8, UInt8, UInt8) {
        let offset = (y * width + x) * 4
        return (bytes[offset], bytes[offset + 1], bytes[offset + 2], bytes[offset + 3])
    }

    func hasDarkPixel(in rect: CGRect) -> Bool {
        darkPixelCount(in: rect) > 0
    }

    func darkPixelCount(in rect: CGRect) -> Int {
        let bounds = rect.intersection(CGRect(x: 0, y: 0, width: width, height: height))
        guard !bounds.isNull else { return 0 }
        var count = 0
        for y in Int(bounds.minY)..<Int(bounds.maxY) {
            for x in Int(bounds.minX)..<Int(bounds.maxX) {
                let color = pixel(x: x, y: y)
                if color.0 < 80, color.1 < 80, color.2 < 80 {
                    count += 1
                }
            }
        }
        return count
    }
}
