import UIKit

@MainActor
enum ScoreRecognitionFixtures {
    static let canvasSize = CGSize(width: 480, height: 240)

    struct Fixture {
        let name: String
        let image: UIImage
        let allowsSuccessZero: Bool
    }

    static func drawDigits(_ digits: String) -> UIImage {
        render { drawText(digits) }
    }

    static func drawBlank() -> UIImage {
        render {}
    }

    static func drawScribble() -> UIImage {
        render { stroke(scribblePath(), lineWidth: 8) }
    }

    static func drawNegative(_ digits: String) -> UIImage {
        render { drawText("-\(digits)") }
    }

    static func drawJunk() -> UIImage {
        render { drawText("abc") }
    }

    static func allFixtures() -> [Fixture] {
        [
            Fixture(name: "digits-0", image: drawDigits("0"), allowsSuccessZero: true),
            Fixture(name: "digits-7", image: drawDigits("7"), allowsSuccessZero: false),
            Fixture(name: "digits-25", image: drawDigits("25"), allowsSuccessZero: false),
            Fixture(name: "digits-105", image: drawDigits("105"), allowsSuccessZero: false),
            Fixture(name: "blank", image: drawBlank(), allowsSuccessZero: false),
            Fixture(name: "scribble", image: drawScribble(), allowsSuccessZero: false),
            Fixture(name: "negative-3", image: drawNegative("3"), allowsSuccessZero: false),
            Fixture(name: "junk", image: drawJunk(), allowsSuccessZero: false),
        ]
    }

    private static func render(_ body: () -> Void) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        return renderer.image { _ in
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: canvasSize))
            body()
        }
    }

    private static func drawText(_ text: String) {
        let font = UIFont(name: "MarkerFelt-Wide", size: 120)
            ?? UIFont.systemFont(ofSize: 120, weight: .bold)
        let string = NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: UIColor.black,
            ]
        )
        let size = string.size()
        string.draw(at: CGPoint(
            x: (canvasSize.width - size.width) / 2,
            y: (canvasSize.height - size.height) / 2
        ))
    }

    private static func scribblePath() -> UIBezierPath {
        let points = [
            CGPoint(x: 70, y: 175),
            CGPoint(x: 145, y: 60),
            CGPoint(x: 215, y: 185),
            CGPoint(x: 295, y: 55),
            CGPoint(x: 365, y: 180),
            CGPoint(x: 415, y: 90),
        ]
        let path = UIBezierPath()
        path.move(to: points[0])
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }

    private static func stroke(_ path: UIBezierPath, lineWidth: CGFloat) {
        UIColor.black.setStroke()
        path.lineWidth = lineWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.stroke()
    }
}
