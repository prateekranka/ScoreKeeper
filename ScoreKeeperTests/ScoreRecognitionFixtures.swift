import Foundation
import PencilKit
import UIKit
@testable import ScoreKeeper

/// Deterministic PencilKit-style handwriting images for Vision integration tests.
@MainActor
enum ScoreRecognitionFixtures {
    static let canvasSize = CGSize(width: 480, height: 240)
    static let renderScale: CGFloat = 2

    struct Fixture {
        let name: String
        let image: UIImage
        let allowsSuccessZero: Bool
    }

    struct ApprovedFixture {
        let name: String
        let expected: String
        let kind: String
        let image: UIImage
    }

    static func drawDigits(_ digits: String) -> UIImage {
        image(for: drawing(for: digits))
    }

    static func drawDigits(_ digits: String, scale: CGFloat, offset: CGPoint) -> UIImage {
        image(for: drawing(for: digits, glyphScale: scale, offset: offset))
    }

    /// Mirrors XCUITest's physical zero gesture: twelve short PencilKit
    /// strokes form a thin polygonal loop instead of one smoothed oval path.
    static func drawSegmentedThinZero() -> UIImage {
        let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        let points = oval(center: center, radius: CGSize(width: 68, height: 108), count: 12)
        let segments = (0..<12).map { [points[$0], points[$0 + 1]] }
        return image(for: drawing(strokes: segments, strokeWidth: 3))
    }

    static func drawCrossedSeven() -> UIImage {
        let glyphWidth: CGFloat = 72
        let glyphHeight: CGFloat = 154
        let origin = CGPoint(
            x: (canvasSize.width - glyphWidth) / 2,
            y: (canvasSize.height - glyphHeight) / 2
        )
        var strokes = glyphStrokes(for: "7").map { stroke in
            stroke.map { point in
                CGPoint(
                    x: origin.x + point.x * glyphWidth,
                    y: origin.y + point.y * glyphHeight
                )
            }
        }
        strokes.append([
            CGPoint(x: origin.x + glyphWidth * 0.30, y: origin.y + glyphHeight * 0.30),
            CGPoint(x: origin.x + glyphWidth * 0.67, y: origin.y + glyphHeight * 0.70),
        ])
        return image(for: drawing(strokes: strokes))
    }

    static func drawTouchingDigits() -> UIImage {
        let firstCenter = CGPoint(x: 190, y: canvasSize.height / 2)
        let secondCenter = CGPoint(x: 290, y: canvasSize.height / 2)
        return image(for: drawing(strokes: [
            oval(center: firstCenter, radius: CGSize(width: 65, height: 80)),
            oval(center: secondCenter, radius: CGSize(width: 65, height: 80)),
        ]))
    }

    static func drawTinyNoise() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = renderScale
        format.opaque = true
        return UIGraphicsImageRenderer(size: canvasSize, format: format).image { _ in
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: canvasSize))
            UIColor.black.setFill()
            UIRectFill(CGRect(x: canvasSize.width / 2, y: canvasSize.height / 2, width: 2, height: 2))
        }
    }

    static func drawBlank() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = renderScale
        format.opaque = true
        return UIGraphicsImageRenderer(size: canvasSize, format: format).image { _ in
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: canvasSize))
        }
    }

    static func drawScribble() -> UIImage {
        image(for: drawing(strokes: [scribbleStroke()]))
    }

    static func drawNegative(_ digits: String) -> UIImage {
        image(for: drawing(for: digits, leadingMinusLength: 0.30))
    }

    static func drawShortNegative(_ digits: String) -> UIImage {
        image(for: drawing(for: digits, leadingMinusLength: 0.16))
    }

    static func drawDetachedCrossbarFour() -> UIImage {
        let glyphWidth: CGFloat = 72
        let glyphHeight: CGFloat = 154
        let origin = CGPoint(
            x: (canvasSize.width - glyphWidth) / 2,
            y: (canvasSize.height - glyphHeight) / 2
        )
        let normalizedStrokes: [[CGPoint]] = [
            [CGPoint(x: 0.70, y: 0.06), CGPoint(x: 0.50, y: 0.50), CGPoint(x: 0.62, y: 0.94)],
            [CGPoint(x: 0.12, y: 0.56), CGPoint(x: 0.45, y: 0.56)],
        ]
        let strokes = normalizedStrokes.map { stroke in
            stroke.map { point in
                CGPoint(x: origin.x + point.x * glyphWidth, y: origin.y + point.y * glyphHeight)
            }
        }
        return image(for: drawing(strokes: strokes))
    }

    static func drawJunk() -> UIImage {
        image(for: drawing(strokes: [
            [
                CGPoint(x: 64, y: 164), CGPoint(x: 98, y: 88), CGPoint(x: 132, y: 164),
                CGPoint(x: 166, y: 88), CGPoint(x: 200, y: 164), CGPoint(x: 234, y: 88),
                CGPoint(x: 268, y: 164), CGPoint(x: 302, y: 88), CGPoint(x: 336, y: 164),
                CGPoint(x: 370, y: 88), CGPoint(x: 404, y: 164),
            ],
            [
                CGPoint(x: 82, y: 76), CGPoint(x: 112, y: 56), CGPoint(x: 142, y: 76),
                CGPoint(x: 172, y: 56), CGPoint(x: 202, y: 76), CGPoint(x: 232, y: 56),
                CGPoint(x: 262, y: 76), CGPoint(x: 292, y: 56), CGPoint(x: 322, y: 76),
                CGPoint(x: 352, y: 56), CGPoint(x: 382, y: 76),
            ],
        ]))
    }

    static func allFixtures() -> [Fixture] {
        [
            Fixture(name: "digits-0", image: drawDigits("0"), allowsSuccessZero: true),
            Fixture(name: "digits-0-segmented-thin", image: drawSegmentedThinZero(), allowsSuccessZero: true),
            Fixture(name: "digits-1", image: drawDigits("1"), allowsSuccessZero: false),
            Fixture(name: "digits-2", image: drawDigits("2"), allowsSuccessZero: false),
            Fixture(name: "digits-3", image: drawDigits("3"), allowsSuccessZero: false),
            Fixture(name: "digits-4", image: drawDigits("4"), allowsSuccessZero: false),
            Fixture(name: "digits-4-detached-crossbar", image: drawDetachedCrossbarFour(), allowsSuccessZero: false),
            Fixture(name: "digits-5", image: drawDigits("5"), allowsSuccessZero: false),
            Fixture(name: "digits-6", image: drawDigits("6"), allowsSuccessZero: false),
            Fixture(name: "digits-7", image: drawDigits("7"), allowsSuccessZero: false),
            Fixture(name: "digits-8", image: drawDigits("8"), allowsSuccessZero: false),
            Fixture(name: "digits-9", image: drawDigits("9"), allowsSuccessZero: false),
            Fixture(name: "digits-12", image: drawDigits("12"), allowsSuccessZero: false),
            Fixture(name: "digits-25", image: drawDigits("25"), allowsSuccessZero: false),
            Fixture(name: "digits-50", image: drawDigits("50"), allowsSuccessZero: false),
            Fixture(name: "digits-99", image: drawDigits("99"), allowsSuccessZero: false),
            Fixture(name: "digits-105", image: drawDigits("105"), allowsSuccessZero: false),
            Fixture(name: "digits-250", image: drawDigits("250"), allowsSuccessZero: false),
            Fixture(name: "digits-105-small-offset", image: drawDigits("105", scale: 0.64, offset: CGPoint(x: -112, y: 16)), allowsSuccessZero: false),
            Fixture(name: "digits-25-large-offset", image: drawDigits("25", scale: 1.18, offset: CGPoint(x: 76, y: -10)), allowsSuccessZero: false),
            Fixture(name: "blank", image: drawBlank(), allowsSuccessZero: false),
            Fixture(name: "scribble", image: drawScribble(), allowsSuccessZero: false),
            Fixture(name: "negative-3", image: drawNegative("3"), allowsSuccessZero: false),
            Fixture(name: "junk", image: drawJunk(), allowsSuccessZero: false),
        ]
    }

    static func recordingSingleFixtures() -> [ApprovedFixture] {
        approvedRecordingFixtures().filter { $0.kind == "recording-single" }
    }

    static func recordingDoubleFixtures() -> [ApprovedFixture] {
        approvedRecordingFixtures().filter { $0.kind == "recording-double" }
    }

    static func approvedRecordingFixtures() -> [ApprovedFixture] {
        approvedRecordingSpecs.map { spec in
            ApprovedFixture(
                name: spec.name,
                expected: spec.expected,
                kind: spec.kind,
                image: bundledImage(named: spec.name)
            )
        }
    }

    static func recordingFixture(named name: String) -> UIImage {
        bundledImage(named: name)
    }

    static func approvedFixtureManifestData() -> Data {
        let url = fixtureURL(named: "manifest", extension: "json")
        do {
            return try Data(contentsOf: url)
        } catch {
            preconditionFailure("Unable to read ScoreRecognition fixture manifest: \(error)")
        }
    }

    private static func image(for drawing: PKDrawing) -> UIImage {
        guard let image = ScoreWritingCanvas.normalizedImage(
            for: drawing,
            canvasSize: canvasSize,
            scale: renderScale
        ) else {
            preconditionFailure("Expected fixture drawing to contain ink")
        }
        return image
    }

    private static func drawing(
        for digits: String,
        glyphScale: CGFloat = 1,
        offset: CGPoint = .zero,
        leadingMinusLength: CGFloat? = nil,
        spacing: CGFloat? = nil
    ) -> PKDrawing {
        let glyphWidth: CGFloat = 72 * glyphScale
        let glyphHeight: CGFloat = 154 * glyphScale
        let glyphSpacing = spacing ?? 20 * glyphScale
        let digitCount = CGFloat(digits.count)
        let totalWidth = digitCount * glyphWidth + max(digitCount - 1, 0) * glyphSpacing
        let origin = CGPoint(
            x: (canvasSize.width - totalWidth) / 2 + offset.x,
            y: (canvasSize.height - glyphHeight) / 2 + offset.y
        )

        var strokes: [[CGPoint]] = []
        if let leadingMinusLength {
            let minusY = origin.y + glyphHeight * 0.52
            let minusStart = origin.x - glyphWidth * 0.48
            strokes.append([
                CGPoint(x: minusStart, y: minusY),
                CGPoint(x: minusStart + glyphWidth * leadingMinusLength, y: minusY),
            ])
        }

        for (index, digit) in digits.enumerated() {
            let glyphOrigin = CGPoint(
                x: origin.x + CGFloat(index) * (glyphWidth + glyphSpacing),
                y: origin.y
            )
            for stroke in glyphStrokes(for: digit) {
                strokes.append(stroke.map { point in
                    CGPoint(
                        x: glyphOrigin.x + point.x * glyphWidth,
                        y: glyphOrigin.y + point.y * glyphHeight
                    )
                })
            }
        }
        return drawing(strokes: strokes)
    }

    private static func glyphStrokes(for digit: Character) -> [[CGPoint]] {
        switch digit {
        case "0":
            return [oval(center: CGPoint(x: 0.5, y: 0.5), radius: CGSize(width: 0.30, height: 0.46))]
        case "1":
            return [[
                CGPoint(x: 0.28, y: 0.22), CGPoint(x: 0.50, y: 0.06),
                CGPoint(x: 0.50, y: 0.94),
            ]]
        case "2":
            return [[
                CGPoint(x: 0.16, y: 0.18), CGPoint(x: 0.30, y: 0.07),
                CGPoint(x: 0.58, y: 0.07), CGPoint(x: 0.76, y: 0.20),
                CGPoint(x: 0.70, y: 0.36), CGPoint(x: 0.50, y: 0.52),
                CGPoint(x: 0.24, y: 0.72), CGPoint(x: 0.18, y: 0.93),
                CGPoint(x: 0.80, y: 0.93),
            ]]
        case "3":
            return [[
                CGPoint(x: 0.18, y: 0.14), CGPoint(x: 0.40, y: 0.06),
                CGPoint(x: 0.66, y: 0.10), CGPoint(x: 0.76, y: 0.24),
                CGPoint(x: 0.67, y: 0.39), CGPoint(x: 0.46, y: 0.47),
                CGPoint(x: 0.67, y: 0.54), CGPoint(x: 0.76, y: 0.68),
                CGPoint(x: 0.68, y: 0.86), CGPoint(x: 0.48, y: 0.95),
                CGPoint(x: 0.22, y: 0.88),
            ]]
        case "4":
            return [
                [CGPoint(x: 0.38, y: 0.06), CGPoint(x: 0.16, y: 0.55), CGPoint(x: 0.84, y: 0.55)],
                [CGPoint(x: 0.52, y: 0.06), CGPoint(x: 0.52, y: 0.94)],
            ]
        case "5":
            return [[
                CGPoint(x: 0.76, y: 0.08), CGPoint(x: 0.20, y: 0.08),
                CGPoint(x: 0.17, y: 0.45), CGPoint(x: 0.53, y: 0.42),
                CGPoint(x: 0.74, y: 0.55), CGPoint(x: 0.70, y: 0.82),
                CGPoint(x: 0.50, y: 0.94), CGPoint(x: 0.20, y: 0.86),
            ]]
        case "6":
            return [[
                CGPoint(x: 0.72, y: 0.10), CGPoint(x: 0.48, y: 0.06),
                CGPoint(x: 0.24, y: 0.24), CGPoint(x: 0.16, y: 0.58),
                CGPoint(x: 0.26, y: 0.86), CGPoint(x: 0.50, y: 0.95),
                CGPoint(x: 0.72, y: 0.82), CGPoint(x: 0.70, y: 0.62),
                CGPoint(x: 0.54, y: 0.50), CGPoint(x: 0.25, y: 0.56),
            ]]
        case "7":
            return [[
                CGPoint(x: 0.12, y: 0.08), CGPoint(x: 0.88, y: 0.08),
                CGPoint(x: 0.78, y: 0.22), CGPoint(x: 0.64, y: 0.44),
                CGPoint(x: 0.50, y: 0.68), CGPoint(x: 0.38, y: 0.94),
            ]]
        case "8":
            return [
                oval(center: CGPoint(x: 0.50, y: 0.27), radius: CGSize(width: 0.25, height: 0.22)),
                oval(center: CGPoint(x: 0.50, y: 0.73), radius: CGSize(width: 0.27, height: 0.24)),
            ]
        case "9":
            return [
                oval(center: CGPoint(x: 0.48, y: 0.27), radius: CGSize(width: 0.27, height: 0.23)),
                [CGPoint(x: 0.72, y: 0.32), CGPoint(x: 0.70, y: 0.62), CGPoint(x: 0.62, y: 0.94)],
            ]
        default:
            return [scribbleStroke()]
        }
    }

    private static func oval(center: CGPoint, radius: CGSize, count: Int = 28) -> [CGPoint] {
        (0...count).map { index in
            let angle = (CGFloat(index) / CGFloat(count)) * 2 * .pi - .pi / 2
            return CGPoint(
                x: center.x + radius.width * cos(angle),
                y: center.y + radius.height * sin(angle)
            )
        }
    }

    private static func scribbleStroke() -> [CGPoint] {
        [
            CGPoint(x: 70, y: 176), CGPoint(x: 142, y: 58), CGPoint(x: 214, y: 184),
            CGPoint(x: 286, y: 56), CGPoint(x: 358, y: 178), CGPoint(x: 418, y: 84),
        ]
    }

    private static func drawing(strokes: [[CGPoint]], strokeWidth: CGFloat = 10) -> PKDrawing {
        let ink = PKInkingTool(.pen, color: .black, width: strokeWidth).ink
        let pkStrokes = strokes.map { points in
            let controlPoints = points.enumerated().map { index, point in
                PKStrokePoint(
                    location: point,
                    timeOffset: TimeInterval(index) * 0.01,
                    size: CGSize(width: strokeWidth, height: strokeWidth),
                    opacity: 1,
                    force: 1,
                    azimuth: 0,
                    altitude: .pi / 2
                )
            }
            let path = PKStrokePath(
                controlPoints: controlPoints,
                creationDate: Date(timeIntervalSinceReferenceDate: 0)
            )
            return PKStroke(
                ink: ink,
                path: path,
                transform: .identity,
                mask: nil
            )
        }
        return PKDrawing(strokes: pkStrokes)
    }

    private static let approvedRecordingSpecs: [ApprovedFixtureSpec] = [
        ApprovedFixtureSpec(name: "recording-3", expected: "3", kind: "recording-single"),
        ApprovedFixtureSpec(name: "recording-crossed-7", expected: "7", kind: "recording-single"),
        ApprovedFixtureSpec(name: "recording-9", expected: "9", kind: "recording-single"),
        ApprovedFixtureSpec(name: "recording-1", expected: "1", kind: "recording-single"),
        ApprovedFixtureSpec(name: "recording-2", expected: "2", kind: "recording-single"),
        ApprovedFixtureSpec(name: "recording-12", expected: "12", kind: "recording-double"),
        ApprovedFixtureSpec(name: "recording-21", expected: "21", kind: "recording-double"),
        ApprovedFixtureSpec(name: "recording-37", expected: "37", kind: "recording-double"),
        ApprovedFixtureSpec(name: "recording-73", expected: "73", kind: "recording-double"),
        ApprovedFixtureSpec(name: "recording-29", expected: "29", kind: "recording-double"),
        ApprovedFixtureSpec(name: "recording-92", expected: "92", kind: "recording-double"),
        ApprovedFixtureSpec(name: "recording-19", expected: "19", kind: "recording-double"),
        ApprovedFixtureSpec(name: "recording-91", expected: "91", kind: "recording-double"),
        ApprovedFixtureSpec(name: "recording-72", expected: "72", kind: "recording-double"),
        ApprovedFixtureSpec(name: "recording-27", expected: "27", kind: "recording-double"),
    ]

    private static func bundledImage(named name: String) -> UIImage {
        let url = fixtureURL(named: name, extension: "png")
        guard let image = UIImage(contentsOfFile: url.path) else {
            preconditionFailure("Unable to decode ScoreRecognition fixture image: \(name).png")
        }
        return image
    }

    private static func fixtureURL(named name: String, extension fileExtension: String) -> URL {
        let bundle = Bundle(for: ScoreRecognitionFixtureBundleToken.self)
        let url = bundle.url(
            forResource: name,
            withExtension: fileExtension,
            subdirectory: "Fixtures/ScoreRecognition"
        ) ?? bundle.url(forResource: name, withExtension: fileExtension)
        guard let url else {
            preconditionFailure("Missing ScoreRecognition fixture: \(name).\(fileExtension)")
        }
        return url
    }

    private struct ApprovedFixtureSpec {
        let name: String
        let expected: String
        let kind: String
    }
}

private final class ScoreRecognitionFixtureBundleToken: NSObject {}

private extension CGFloat {
    static var pi: CGFloat { CGFloat(Double.pi) }
}
