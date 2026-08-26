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

/// Recognizes handwritten round scores from a captured canvas image.
enum ScoreRecognizer {
    static let defaultConfidenceThreshold = 0.35

    static func recognize(
        _ image: UIImage,
        recognitionLevel: VNRequestTextRecognitionLevel = .accurate
    ) async -> ScoreRecognitionResult {
        guard let cgImage = image.cgImage else { return .error }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil else {
                    continuation.resume(returning: .error)
                    return
                }
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                continuation.resume(returning: interpret(fragments: extractFragments(from: observations)))
            }
            request.recognitionLevel = recognitionLevel
            request.usesLanguageCorrection = false
            request.customWords = []

            do {
                try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
            } catch {
                continuation.resume(returning: .error)
            }
        }
    }

    /// Reduces Vision observations to clean, minus-free digit fragments.
    ///
    /// For each observation the highest-confidence candidate wins, provided its
    /// raw string contains no "-" (a minus anywhere marks a negative attempt and
    /// the candidate is rejected, never silently stripped) and it carries at
    /// least one ASCII digit. Candidates below the confidence threshold drop out.
    static func extractFragments(from observations: [VNRecognizedTextObservation]) -> [ScoreRecognitionFragment] {
        observations.compactMap { observation in
            let candidate = observation.topCandidates(3)
                .filter { !$0.string.contains("-") }
                .filter { !$0.string.filter(\.isNumber).isEmpty }
                .max { $0.confidence < $1.confidence }
            guard let candidate, Double(candidate.confidence) >= defaultConfidenceThreshold else { return nil }
            return ScoreRecognitionFragment(
                digits: candidate.string.filter(\.isNumber),
                minX: observation.boundingBox.minX,
                confidence: Double(candidate.confidence)
            )
        }
    }

    /// Turns candidate fragments into a single score reading.
    ///
    /// Fragments containing a minus are rejected outright (negative attempts are
    /// never interpreted as positive values). Remaining fragments are stripped to
    /// ASCII digits, gated on the confidence threshold, ordered left-to-right by
    /// `minX`, and joined. The result is capped at 9999.
    static func interpret(fragments: [ScoreRecognitionFragment]) -> ScoreRecognitionResult {
        let accepted = fragments
            .filter { !$0.digits.contains("-") }
            .compactMap { fragment -> ScoreRecognitionFragment? in
                let digits = fragment.digits.filter(\.isNumber)
                guard !digits.isEmpty else { return nil }
                return ScoreRecognitionFragment(digits: digits, minX: fragment.minX, confidence: fragment.confidence)
            }
            .filter { $0.confidence >= defaultConfidenceThreshold }
            .sorted { $0.minX < $1.minX }

        let joined = accepted.map(\.digits).joined()
        guard !joined.isEmpty else { return .unreadable }

        let value = min(Int(joined) ?? 9999, 9999)
        let confidence = accepted.map(\.confidence).reduce(0, +) / Double(accepted.count)
        return .success(value: value, confidence: confidence)
    }
}

private extension Character {
    var isNumber: Bool { isASCII && isNumberASCII }
    private var isNumberASCII: Bool { ("0"..."9").contains(String(self)) }
}

private extension String {
    var isASCII: Bool { unicodeScalars.allSatisfy { $0.isASCII } }
}
