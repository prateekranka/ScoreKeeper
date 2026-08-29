import PencilKit
import XCTest

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

    func testNormalizedOutputIs512By256PixelsAtEveryRequestedScale() {
        let drawing = drawing([[CGPoint(x: 40, y: 40), CGPoint(x: 180, y: 100)]])
        for scale in [CGFloat(1), 2, 3] {
            let image = try XCTUnwrap(ScoreWritingCanvas.normalizedImage(
                for: drawing, canvasSize: CGSize(width: 320, height: 160), scale: scale
            ))
            XCTAssertEqual(image.cgImage?.width, 512)
            XCTAssertEqual(image.cgImage?.height, 256)
        }
    }

    func testOutputHasOpaqueWhiteBackgroundAndDarkInk() throws {
        let image = try XCTUnwrap(ScoreWritingCanvas.normalizedImage(
            for: drawing([[CGPoint(x: 80, y: 70), CGPoint(x: 240, y: 70)]]),
            canvasSize: CGSize(width: 320, height: 160), scale: 2
        ))
        let cgImage = try XCTUnwrap(image.cgImage)
        let background = pixel(cgImage, x: 0, y: 0)
        XCTAssertEqual(background.0, 255)
        XCTAssertEqual(background.1, 255)
        XCTAssertEqual(background.2, 255)
        XCTAssertEqual(background.3, 255)
        XCTAssertTrue((0..<cgImage.width).contains { x in
            let color = pixel(cgImage, x: x, y: cgImage.height / 2)
            return color.0 < 80 && color.1 < 80 && color.2 < 80
        })
    }

    func testAsymmetricDrawingRemainsUpright() throws {
        let image = try XCTUnwrap(ScoreWritingCanvas.normalizedImage(
            for: drawing([[CGPoint(x: 60, y: 40), CGPoint(x: 220, y: 40), CGPoint(x: 220, y: 120)]]),
            canvasSize: CGSize(width: 320, height: 160), scale: 2
        ))
        let cgImage = try XCTUnwrap(image.cgImage)
        XCTAssertTrue(hasDarkPixel(cgImage, in: CGRect(x: 300, y: 145, width: 80, height: 70)))
        XCTAssertFalse(hasDarkPixel(cgImage, in: CGRect(x: 300, y: 40, width: 80, height: 70)))
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
        XCTAssertTrue(hasDarkPixel(cgImage, in: CGRect(x: 0, y: 80, width: 35, height: 96)))
        XCTAssertTrue(hasDarkPixel(cgImage, in: CGRect(x: 477, y: 80, width: 35, height: 96)))
        XCTAssertTrue(hasDarkPixel(cgImage, in: CGRect(x: 208, y: 0, width: 96, height: 35)))
        XCTAssertTrue(hasDarkPixel(cgImage, in: CGRect(x: 208, y: 221, width: 96, height: 35)))
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

    private func hasDarkPixel(_ image: CGImage, in rect: CGRect) -> Bool {
        let bounds = rect.intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return stride(from: Int(bounds.minY), to: Int(bounds.maxY), by: 2).contains { y in
            stride(from: Int(bounds.minX), to: Int(bounds.maxX), by: 2).contains { x in
                let p = pixel(image, x: x, y: y)
                return p.0 < 80 && p.1 < 80 && p.2 < 80
            }
        }
    }

    private func pixel(_ image: CGImage, x: Int, y: Int) -> (UInt8, UInt8, UInt8, UInt8) {
        let data = image.dataProvider!.data! as Data
        let offset = (y * image.bytesPerRow) + (x * 4)
        return (data[offset], data[offset + 1], data[offset + 2], data[offset + 3])
    }
}
