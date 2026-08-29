import UIKit
import Vision

/// Result of an attempt to read a handwritten round score from a captured canvas image.
enum ScoreRecognitionResult: Equatable {
    case success(value: Int, confidence: Double)
    case noInk
    case unreadable
    case error
}

/// One accepted digit fragment from a recognized text observation.
struct ScoreRecognitionFragment: Equatable {
    let digits: String
    let minX: CGFloat
    let confidence: Double
}

/// Calibrated acceptance gates supplied by the model-training workstream.
/// There is intentionally no production default until a PipCount model has
/// passed the writer-disjoint recognition gate.
struct ScoreDigitAcceptancePolicy: Equatable, Sendable {
    let minimumProbability: Double
    let minimumMargin: Double

    var isValid: Bool {
        minimumProbability.isFinite
            && minimumMargin.isFinite
            && (0...1).contains(minimumProbability)
            && (0...1).contains(minimumMargin)
    }
}

/// Recognizes handwritten round scores from a captured canvas image.
enum ScoreRecognizer {
    static let defaultConfidenceThreshold = 0.35

    /// Runs the opt-in digit pipeline with an already segmented image.
    ///
    /// The existing Vision recognizer remains the default entry point until an
    /// accepted PipCount model and calibrated policy are available. Supplying
    /// segments explicitly keeps this boundary independent from Task 2's
    /// segmenter implementation and makes it possible to test without a model.
    static func recognize(
        segments: [ScoreDigitInput],
        classifier: any ScoreDigitClassifying,
        acceptance: ScoreDigitAcceptancePolicy
    ) async -> ScoreRecognitionResult {
        guard acceptance.isValid else { return .error }
        guard !segments.isEmpty else { return .noInk }
        guard segments.count <= 2 else { return .unreadable }

        var digits = ""
        var probabilities: [Double] = []
        probabilities.reserveCapacity(segments.count)

        for segment in segments {
            let prediction: ScoreDigitPrediction
            do {
                prediction = try await classifier.classify(segment)
            } catch {
                return .error
            }

            guard accepts(prediction, using: acceptance) else { return .unreadable }
            digits.append(String(prediction.digit))
            probabilities.append(prediction.probability)
        }

        guard let value = Int(digits), (0...99).contains(value) else {
            return .unreadable
        }

        return .success(value: value, confidence: probabilities.min() ?? 0)
    }

    /// Runs the opt-in digit pipeline after validating the original capture.
    /// The segmenter is injected so Task 2 can provide its deterministic
    /// implementation without coupling this workstream to a guessed API.
    static func recognize(
        _ image: UIImage,
        segmenter: @Sendable (CGImage) -> [ScoreDigitInput]?,
        classifier: any ScoreDigitClassifying,
        acceptance: ScoreDigitAcceptancePolicy
    ) async -> ScoreRecognitionResult {
        guard acceptance.isValid else { return .error }
        guard let cgImage = image.cgImage,
              let analysis = inkAnalysis(from: cgImage)
        else {
            return .error
        }

        guard !significantInkComponents(in: analysis).isEmpty else { return .noInk }
        guard !containsLeadingMinus(in: analysis) else { return .unreadable }
        guard let segments = segmenter(cgImage), !segments.isEmpty else {
            return .unreadable
        }

        return await recognize(
            segments: segments,
            classifier: classifier,
            acceptance: acceptance
        )
    }

    /// Legacy Vision fallback kept until an accepted PipCount model is bundled
    /// and wired to the explicit classifier pipeline above.
    static func recognize(
        _ image: UIImage,
        recognitionLevel: VNRequestTextRecognitionLevel = .accurate
    ) async -> ScoreRecognitionResult {
        guard let cgImage = image.cgImage else { return .error }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: recognize(cgImage, recognitionLevel: recognitionLevel))
            }
        }
    }

    private static func recognize(
        _ cgImage: CGImage,
        recognitionLevel: VNRequestTextRecognitionLevel
    ) -> ScoreRecognitionResult {
        guard let analysis = inkAnalysis(from: cgImage) else { return .error }

        // Vision's fast recognizer can discard a separate leading minus and
        // return only the positive digits. Reject that unsupported syntax from
        // the normalized ink itself before either OCR pass can lose it.
        guard !containsLeadingMinus(in: analysis) else { return .unreadable }

        let primary = recognizeText(cgImage, recognitionLevel: recognitionLevel)
        guard primary == .unreadable else { return primary }

        if recognitionLevel == .accurate {
            // Accurate recognition is best for multi-digit scores, but on current
            // Vision models it can return no observations for isolated handwritten
            // 0, 1, 7, 8, and 99. Fast recognition is a narrow fallback only when
            // the accurate pass found nothing usable.
            let fallback = recognizeText(cgImage, recognitionLevel: .fast)
            guard fallback == .unreadable else { return fallback }
        }

        // Vision can classify a thin, segmented zero gesture as a bullet. Only
        // recover zero when the ink itself is one centered closed ring; arbitrary
        // unreadable ink must stay unreadable rather than becoming phantom zero.
        return looksLikeClosedZero(in: analysis)
            ? .success(value: 0, confidence: defaultConfidenceThreshold)
            : .unreadable
    }

    private static func accepts(
        _ prediction: ScoreDigitPrediction,
        using acceptance: ScoreDigitAcceptancePolicy
    ) -> Bool {
        guard (0...9).contains(prediction.digit),
              prediction.probability.isFinite,
              prediction.runnerUpProbability.isFinite,
              (0...1).contains(prediction.probability),
              (0...1).contains(prediction.runnerUpProbability)
        else {
            return false
        }

        return prediction.probability >= acceptance.minimumProbability
            && prediction.margin >= acceptance.minimumMargin
    }

    private static func recognizeText(
        _ cgImage: CGImage,
        recognitionLevel: VNRequestTextRecognitionLevel
    ) -> ScoreRecognitionResult {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = recognitionLevel
        request.usesLanguageCorrection = false
        request.automaticallyDetectsLanguage = false
        request.recognitionLanguages = ["en-US"]
        request.minimumTextHeight = 0
        request.customWords = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]

        do {
            try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
        } catch {
            return .error
        }

        let observations = request.results ?? []
        if observations.contains(where: { observation in
            observation.topCandidates(3).contains {
                containsNegativeMarker(in: $0.string)
            }
        }) {
            // A minus may be returned as a separate observation from its
            // digits. Reject the complete reading instead of allowing the
            // remaining positive digits to become a score.
            return .unreadable
        }
        return interpret(fragments: extractFragments(from: observations))
    }

    private static func containsNegativeMarker(in text: String) -> Bool {
        text.contains("-") || text.contains("−")
    }

    /// Converts a legacy Vision candidate to deliberate score syntax.
    ///
    /// This remains only for the live fallback path while the accepted
    /// PipCount classifier is unavailable. It accepts ASCII digits and
    /// whitespace only; letters and punctuation never become plausible scores.
    static func normalizedDigits(from text: String) -> String? {
        guard !containsNegativeMarker(in: text) else { return nil }

        var digits = ""
        for character in text {
            if character.isASCIIDigit {
                digits.append(character)
            } else if character.isWhitespace {
                continue
            } else {
                return nil
            }
        }
        return digits.isEmpty ? nil : digits
    }

    /// Reduces Vision observations to clean, minus-free digit fragments.
    static func extractFragments(from observations: [VNRecognizedTextObservation]) -> [ScoreRecognitionFragment] {
        observations.compactMap { observation in
            for candidate in observation.topCandidates(3) {
                let confidence = Double(candidate.confidence)
                guard confidence >= defaultConfidenceThreshold,
                      let digits = normalizedDigits(from: candidate.string)
                else { continue }

                return ScoreRecognitionFragment(
                    digits: digits,
                    minX: observation.boundingBox.minX,
                    confidence: confidence
                )
            }
            return nil
        }
    }

    /// Turns candidate fragments into a single score reading.
    ///
    /// Fragments must contain only ASCII digits. Low-confidence valid digit fragments
    /// are discarded, then remaining fragments are ordered left-to-right and joined.
    /// Only one- and two-digit scores in `0...99` are accepted.
    static func interpret(fragments: [ScoreRecognitionFragment]) -> ScoreRecognitionResult {
        guard fragments.allSatisfy({ fragment in
            fragment.digits.allSatisfy(\.isASCIIDigit)
        }) else {
            return .unreadable
        }

        let accepted = fragments
            .filter { !$0.digits.isEmpty && $0.confidence >= defaultConfidenceThreshold }
            .sorted { $0.minX < $1.minX }

        let joined = accepted.map(\.digits).joined()
        guard (1...2).contains(joined.count),
              let value = Int(joined),
              (0...99).contains(value) else {
            return .unreadable
        }

        let confidence = accepted.map(\.confidence).reduce(0, +) / Double(accepted.count)
        return .success(value: value, confidence: confidence)
    }

    /// Detects a disconnected horizontal mark immediately to the left of the
    /// main digit ink. This is the shape Vision's fast pass otherwise drops from
    /// a handwritten negative such as `-3`.
    static func containsLeadingMinus(in image: UIImage) -> Bool {
        guard let analysis = inkAnalysis(from: image) else { return false }
        return containsLeadingMinus(in: analysis)
    }

    private static func containsLeadingMinus(in analysis: InkAnalysis) -> Bool {
        let digitComponents = significantInkComponents(in: analysis)
        guard let leftmostDigit = digitComponents.min(by: { $0.minX < $1.minX }) else {
            return false
        }

        let minimumArea = minimumSignificantArea(in: analysis.raster)
        let digitHeight = Double(leftmostDigit.height)
        let digitMidY = Double(leftmostDigit.minY + leftmostDigit.maxY) / 2
        let minimumWidthRatio = 0.10
        let maximumWidthRatio = 0.65
        let maximumHeightRatio = 0.24
        let minimumAspectRatio = 1.7
        let maximumVerticalOffsetRatio = 0.25

        return analysis.inkComponents.contains { component in
            let componentWidth = Double(component.width)
            let componentHeight = Double(component.height)
            let componentMidY = Double(component.minY + component.maxY) / 2

            return component.area >= minimumArea
                && component.maxX < leftmostDigit.minX
                && componentWidth >= digitHeight * minimumWidthRatio
                && componentWidth <= digitHeight * maximumWidthRatio
                && componentHeight <= digitHeight * maximumHeightRatio
                && componentWidth / max(componentHeight, 1) >= minimumAspectRatio
                && abs(componentMidY - digitMidY) <= digitHeight * maximumVerticalOffsetRatio
        }
    }

    /// Recognizes a literal zero from ink topology when Vision returns no digit.
    /// One dominant ring with one large centered hole is accepted; open scribbles,
    /// solid marks, 8s, and multi-digit scores are not.
    static func looksLikeClosedZero(in image: UIImage) -> Bool {
        guard let analysis = inkAnalysis(from: image) else { return false }
        return looksLikeClosedZero(in: analysis)
    }

    private static func looksLikeClosedZero(in analysis: InkAnalysis) -> Bool {
        let raster = analysis.raster
        let significantInk = significantInkComponents(in: analysis)
        guard significantInk.count == 1, let glyph = significantInk.first else { return false }

        let aspectRatio = Double(glyph.width) / Double(glyph.height)
        guard RecognitionGeometry.zeroAspectRatio.contains(aspectRatio) else { return false }

        let glyphArea = Double(glyph.width * glyph.height)
        let holes = enclosedWhiteComponents(in: raster).filter { hole in
            hole.minX > glyph.minX
                && hole.maxX < glyph.maxX
                && hole.minY > glyph.minY
                && hole.maxY < glyph.maxY
                && Double(hole.area) >= glyphArea * RecognitionGeometry.minimumCandidateHoleAreaRatio
        }
        guard holes.count == 1, let hole = holes.first else { return false }

        let holeWidthRatio = Double(hole.width) / Double(glyph.width)
        let holeHeightRatio = Double(hole.height) / Double(glyph.height)
        let holeAreaRatio = Double(hole.area) / glyphArea
        let glyphMidX = Double(glyph.minX + glyph.maxX) / 2
        let glyphMidY = Double(glyph.minY + glyph.maxY) / 2
        let holeMidX = Double(hole.minX + hole.maxX) / 2
        let holeMidY = Double(hole.minY + hole.maxY) / 2

        return holeWidthRatio >= RecognitionGeometry.minimumHoleWidthRatio
            && holeHeightRatio >= RecognitionGeometry.minimumHoleHeightRatio
            && holeAreaRatio >= RecognitionGeometry.minimumAcceptedHoleAreaRatio
            && abs(holeMidX - glyphMidX) <= Double(glyph.width) * RecognitionGeometry.maximumHoleOffsetRatio
            && abs(holeMidY - glyphMidY) <= Double(glyph.height) * RecognitionGeometry.maximumHoleOffsetRatio
    }

    private static func significantInkComponents(in analysis: InkAnalysis) -> [InkComponent] {
        let minimumArea = minimumSignificantArea(in: analysis.raster)
        return analysis.inkComponents.filter {
            $0.area >= minimumArea
                && Double($0.height) >= Double(analysis.raster.height) * RecognitionGeometry.minimumGlyphHeightRatio
        }
    }

    private static func minimumSignificantArea(in raster: InkRaster) -> Int {
        max(
            RecognitionGeometry.minimumComponentArea,
            Int(Double(raster.width * raster.height) * RecognitionGeometry.minimumComponentAreaRatio)
        )
    }

    private static func inkAnalysis(from image: UIImage) -> InkAnalysis? {
        guard let cgImage = image.cgImage else { return nil }
        return inkAnalysis(from: cgImage)
    }

    private static func inkAnalysis(from cgImage: CGImage) -> InkAnalysis? {
        guard let raster = inkRaster(from: cgImage) else { return nil }
        let components = connectedComponents(in: raster) { $0 < RecognitionGeometry.inkPixelThreshold }
        return InkAnalysis(raster: raster, inkComponents: components)
    }

    private static func inkRaster(from cgImage: CGImage) -> InkRaster? {
        let sourceMaxDimension = max(cgImage.width, cgImage.height)
        guard sourceMaxDimension > 0 else { return nil }
        let analysisScale = min(1, 512 / Double(sourceMaxDimension))
        let width = max(1, Int((Double(cgImage.width) * analysisScale).rounded()))
        let height = max(1, Int((Double(cgImage.height) * analysisScale).rounded()))
        var pixels = [UInt8](repeating: 255, count: width * height)

        let rendered = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return false }

            context.setFillColor(gray: 1, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            context.interpolationQuality = .medium
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        return rendered ? InkRaster(pixels: pixels, width: width, height: height) : nil
    }

    private static func enclosedWhiteComponents(in raster: InkRaster) -> [InkComponent] {
        connectedComponents(in: raster, excludingExterior: true) {
            $0 > RecognitionGeometry.enclosedWhitePixelThreshold
        }
    }

    private static func connectedComponents(
        in raster: InkRaster,
        excludingExterior: Bool = false,
        matching: (UInt8) -> Bool
    ) -> [InkComponent] {
        let width = raster.width
        let height = raster.height
        var visited = [Bool](repeating: false, count: raster.pixels.count)
        var queue: [Int] = []

        func component(startingAt start: Int) -> InkComponent {
            visited[start] = true
            queue.removeAll(keepingCapacity: true)
            queue.append(start)
            var head = 0
            var minX = start % width
            var maxX = minX
            var minY = start / width
            var maxY = minY
            var area = 0

            while head < queue.count {
                let index = queue[head]
                head += 1
                area += 1
                let x = index % width
                let y = index / width
                minX = min(minX, x)
                maxX = max(maxX, x)
                minY = min(minY, y)
                maxY = max(maxY, y)

                for neighborY in max(0, y - 1)...min(height - 1, y + 1) {
                    for neighborX in max(0, x - 1)...min(width - 1, x + 1) {
                        let neighbor = neighborY * width + neighborX
                        guard !visited[neighbor], matching(raster.pixels[neighbor]) else { continue }
                        visited[neighbor] = true
                        queue.append(neighbor)
                    }
                }
            }
            return InkComponent(minX: minX, maxX: maxX, minY: minY, maxY: maxY, area: area)
        }

        if excludingExterior {
            for x in 0..<width {
                for start in [x, (height - 1) * width + x]
                    where matching(raster.pixels[start]) && !visited[start] {
                    _ = component(startingAt: start)
                }
            }
            for y in 0..<height {
                for start in [y * width, y * width + width - 1]
                    where matching(raster.pixels[start]) && !visited[start] {
                    _ = component(startingAt: start)
                }
            }
        }

        var components: [InkComponent] = []
        for start in raster.pixels.indices
            where matching(raster.pixels[start]) && !visited[start] {
            components.append(component(startingAt: start))
        }
        return components
    }

    private struct InkAnalysis {
        let raster: InkRaster
        let inkComponents: [InkComponent]
    }

    private struct InkRaster {
        let pixels: [UInt8]
        let width: Int
        let height: Int
    }

    private struct InkComponent {
        let minX: Int
        let maxX: Int
        let minY: Int
        let maxY: Int
        let area: Int

        var width: Int { maxX - minX + 1 }
        var height: Int { maxY - minY + 1 }
    }
}

private enum RecognitionGeometry {
    static let inkPixelThreshold: UInt8 = 160
    static let enclosedWhitePixelThreshold: UInt8 = 200
    static let zeroAspectRatio: ClosedRange<Double> = 0.30...0.90
    static let minimumCandidateHoleAreaRatio = 0.12
    static let minimumHoleWidthRatio = 0.38
    static let minimumHoleHeightRatio = 0.48
    static let minimumAcceptedHoleAreaRatio = 0.28
    static let maximumHoleOffsetRatio = 0.18
    static let minimumGlyphHeightRatio = 0.28
    static let minimumComponentArea = 12
    static let minimumComponentAreaRatio = 0.001
}

private extension Character {
    var isASCIIDigit: Bool {
        unicodeScalars.count == 1 && ("0"..."9").contains(String(self))
    }
}
