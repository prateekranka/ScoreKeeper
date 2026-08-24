import UIKit
import Vision

/// Recognizes handwritten round scores from a captured canvas image.
enum ScoreRecognizer {
    static func recognize(_ image: UIImage) async -> Int? {
        guard let cgImage = image.cgImage else { return nil }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let fragments = observations.compactMap { observation -> (String, CGFloat)? in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    let digits = candidate.string.filter(\.isNumber)
                    guard !digits.isEmpty else { return nil }
                    return (digits, observation.boundingBox.minX)
                }
                .sorted { $0.1 < $1.1 }

                let value = Int(fragments.map(\.0).joined())
                    .map { min(9999, max(-9999, $0)) }
                continuation.resume(returning: value)
            }
            request.recognitionLevel = .fast
            request.usesLanguageCorrection = false
            request.customWords = []

            do {
                try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }
}

private extension Character {
    var isNumber: Bool { isASCII && isNumberASCII }
    private var isNumberASCII: Bool { ("0"..."9").contains(String(self)) }
}

private extension String {
    var isASCII: Bool { unicodeScalars.allSatisfy { $0.isASCII } }
}
