/// Immutable normalized grayscale pixels safe to transfer into a classifier.
///
/// The production Core ML adapter is intentionally absent until a model passes
/// the writer-disjoint quality gate. This value boundary avoids transferring a
/// mutable, non-Sendable `CVPixelBuffer` between concurrency domains.
struct ScoreDigitInput: Equatable, Sendable {
    let width: Int
    let height: Int
    let pixels: [UInt8]

    init?(width: Int = 28, height: Int = 28, pixels: [UInt8]) {
        guard width > 0,
              height > 0,
              pixels.count == width * height
        else {
            return nil
        }
        self.width = width
        self.height = height
        self.pixels = pixels
    }
}

/// Raw output from one digit classification. A digit outside `0...9` is
/// reserved for the model's reject class and is rejected by the recognizer.
struct ScoreDigitPrediction: Equatable, Sendable {
    let digit: Int
    let probability: Double
    let runnerUpProbability: Double

    var margin: Double {
        probability - runnerUpProbability
    }
}

/// Replaceable inference boundary for a future gate-passing PipCount model.
protocol ScoreDigitClassifying: Sendable {
    func classify(_ input: ScoreDigitInput) async throws -> ScoreDigitPrediction
}

enum ScoreDigitClassifierError: Error, Equatable, Sendable {
    case modelUnavailable
    case inferenceFailed
    case invalidModelOutput
}
