import Foundation
import CoreML
import ImageIO
import Vision

func respond(_ value: [String: Any]) {
    if let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]) {
        FileHandle.standardOutput.write(data)
    }
}

func digits(_ text: String) -> String? {
    let compact = text.filter { !$0.isWhitespace }
    guard !compact.isEmpty, compact.utf8.allSatisfy({ (48...57).contains($0) }) else { return nil }
    return compact
}

let data = FileHandle.standardInput.readDataToEndOfFile()
guard data.count <= 1_048_576,
      let source = CGImageSourceCreateWithData(data as CFData, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
      image.width <= 2048, image.height <= 2048 else {
    respond(["status": "unreadable"])
    exit(0)
}

func read(_ level: VNRequestTextRecognitionLevel) throws -> (Int, Float)? {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = level
    request.recognitionLanguages = ["en-US"]
    request.usesLanguageCorrection = false
    request.automaticallyDetectsLanguage = false
    request.minimumTextHeight = 0
    if #available(macOS 14.0, *) {
        for (stage, devices) in try request.supportedComputeStageDevices {
            if let cpu = devices.first(where: { if case .cpu = $0 { return true }; return false }) {
                request.setComputeDevice(cpu, for: stage)
            }
        }
    }
    try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
    let observations = (request.results ?? []).sorted { $0.boundingBox.minX < $1.boundingBox.minX }
    guard !observations.isEmpty else { return nil }
    var fragments: [String] = []
    var confidence: Float = 1
    for observation in observations {
        guard let candidate = observation.topCandidates(3).first(where: { $0.confidence >= 0.35 && digits($0.string) != nil }),
              let value = digits(candidate.string) else { return nil }
        fragments.append(value)
        confidence = min(confidence, candidate.confidence)
    }
    let combined = fragments.joined()
    guard combined.count <= 2, let value = Int(combined), (0...99).contains(value) else { return nil }
    return (value, confidence)
}

do {
    if let result = try read(.accurate) ?? read(.fast) {
        respond(["status": "ready", "value": result.0, "confidence": result.1])
    } else {
        respond(["status": "unreadable"])
    }
} catch {
    respond(["status": "error"])
}
