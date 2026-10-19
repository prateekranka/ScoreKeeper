import Foundation
import CoreML
import CoreVideo

let configuration = MLModelConfiguration()
configuration.computeUnits = .cpuOnly
let modelURL = URL(fileURLWithPath: CommandLine.arguments[1])
let compiledURL = try MLModel.compileModel(at: modelURL)
let model = try MLModel(contentsOf: compiledURL, configuration: configuration)
if CommandLine.arguments.contains("--describe") {
    print(model.modelDescription)
    exit(0)
}
let inputName = model.modelDescription.inputDescriptionsByName.keys.first!
let outputName = model.modelDescription.predictedProbabilitiesName!
while let line = readLine() {
    do {
        let images = try JSONSerialization.jsonObject(with: Data(line.utf8)) as! [[Double]]
        var predictions: [[Double]] = []
        for pixels in images {
            guard pixels.count == 784 else { throw NSError(domain: "Input", code: 1) }
            var optionalBuffer: CVPixelBuffer?
            guard CVPixelBufferCreate(kCFAllocatorDefault, 28, 28, kCVPixelFormatType_OneComponent8, nil, &optionalBuffer) == kCVReturnSuccess, let buffer = optionalBuffer else { throw NSError(domain: "Buffer", code: 1) }
            CVPixelBufferLockBaseAddress(buffer, [])
            let address = CVPixelBufferGetBaseAddress(buffer)!.assumingMemoryBound(to: UInt8.self)
            let stride = CVPixelBufferGetBytesPerRow(buffer)
            for y in 0..<28 {
                for x in 0..<28 { address[y * stride + x] = UInt8(clamping: Int((pixels[y * 28 + x] * 255).rounded())) }
            }
            CVPixelBufferUnlockBaseAddress(buffer, [])
            let provider = try MLDictionaryFeatureProvider(dictionary: [inputName: MLFeatureValue(pixelBuffer: buffer)])
            let result = try model.prediction(from: provider)
            let probabilities = result.featureValue(for: outputName)!.dictionaryValue
            predictions.append((0..<10).map { probabilities[String($0)]?.doubleValue ?? probabilities[NSNumber(value: $0)]?.doubleValue ?? 0 })
        }
        let data = try JSONSerialization.data(withJSONObject: predictions)
        FileHandle.standardOutput.write(data + Data([10]))
    } catch {
        FileHandle.standardOutput.write(Data("null\n".utf8))
    }
}
