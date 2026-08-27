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

    static func drawDigits(_ digits: String) -> UIImage {
        image(for: drawing(for: digits))
    }

    static func drawDigits(_ digits: String, scale: CGFloat, offset: CGPoint) -> UIImage {
        image(for: drawing(for: digits, glyphScale: scale, offset: offset))
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
        image(for: drawing(for: digits, includeLeadingMinus: true))
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
            Fixture(name: "digits-1", image: drawDigits("1"), allowsSuccessZero: false),
            Fixture(name: "digits-2", image: drawDigits("2"), allowsSuccessZero: false),
            Fixture(name: "digits-7", image: drawDigits("7"), allowsSuccessZero: false),
            Fixture(name: "digits-8", image: drawDigits("8"), allowsSuccessZero: false),
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
        includeLeadingMinus: Bool = false
    ) -> PKDrawing {
        let glyphWidth: CGFloat = 72 * glyphScale
        let glyphHeight: CGFloat = 154 * glyphScale
        let spacing: CGFloat = 20 * glyphScale
        let digitCount = CGFloat(digits.count)
        let totalWidth = digitCount * glyphWidth + max(digitCount - 1, 0) * spacing
        let origin = CGPoint(
            x: (canvasSize.width - totalWidth) / 2 + offset.x,
            y: (canvasSize.height - glyphHeight) / 2 + offset.y
        )

        var strokes: [[CGPoint]] = []
        if includeLeadingMinus {
            let minusY = origin.y + glyphHeight * 0.52
            let minusStart = origin.x - glyphWidth * 0.48
            strokes.append([
                CGPoint(x: minusStart, y: minusY),
                CGPoint(x: minusStart + glyphWidth * 0.30, y: minusY),
            ])
        }

        for (index, digit) in digits.enumerated() {
            let glyphOrigin = CGPoint(
                x: origin.x + CGFloat(index) * (glyphWidth + spacing),
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
                [CGPoint(x: 0.70, y: 0.06), CGPoint(x: 0.16, y: 0.66), CGPoint(x: 0.82, y: 0.66)],
                [CGPoint(x: 0.62, y: 0.06), CGPoint(x: 0.62, y: 0.94)],
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
                CGPoint(x: 0.14, y: 0.08), CGPoint(x: 0.84, y: 0.08),
                CGPoint(x: 0.52, y: 0.42), CGPoint(x: 0.28, y: 0.94),
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

    private static func drawing(strokes: [[CGPoint]]) -> PKDrawing {
        let ink = PKInk(.pen, color: .black)
        let pkStrokes = strokes.map { points in
            let controlPoints = points.enumerated().map { index, point in
                PKStrokePoint(
                    location: point,
                    timeOffset: TimeInterval(index) * 0.01,
                    size: CGSize(width: 10, height: 10),
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
}

private extension CGFloat {
    static var pi: CGFloat { CGFloat(Double.pi) }
}
