import CoreGraphics
import UIKit

enum ScoreDigitSegmentation: Equatable {
    case noInk
    case digits([CGImage])
    case ambiguous
    case unsupported

    static func == (lhs: ScoreDigitSegmentation, rhs: ScoreDigitSegmentation) -> Bool {
        switch (lhs, rhs) {
        case (.noInk, .noInk), (.ambiguous, .ambiguous), (.unsupported, .unsupported):
            return true
        case let (.digits(left), .digits(right)):
            return left.count == right.count
                && zip(left, right).allSatisfy { pair in pair.0 === pair.1 }
        default:
            return false
        }
    }
}

struct ScoreDigitSegmenter {
    static func segment(_ image: CGImage) -> ScoreDigitSegmentation {
        if ScoreRecognizer.containsLeadingMinus(in: UIImage(cgImage: image)) {
            return .unsupported
        }
        guard let raster = InkRaster(image: image) else { return .ambiguous }
        let mask = meaningfulMask(in: raster)
        guard let inkBounds = bounds(of: mask, width: raster.width, height: raster.height) else {
            return .noInk
        }

        let runs = mergeSmallGaps(
            in: occupiedRuns(in: mask, raster: raster, bounds: inkBounds),
            maximumGap: max(4, Int((Double(inkBounds.height) * Geometry.internalGapRatio).rounded(.up)))
        )
        guard !runs.isEmpty else { return .noInk }
        guard runs.count <= 2 else { return .unsupported }

        let groupBounds = runs.compactMap { run in
            bounds(
                of: mask,
                width: raster.width,
                height: raster.height,
                xRange: run.start..<run.end,
                yRange: inkBounds.minY..<inkBounds.maxY
            )
        }
        guard groupBounds.count == runs.count else { return .ambiguous }
        guard groupBounds.allSatisfy({ isPlausibleGlyph($0, in: inkBounds) }) else {
            return .ambiguous
        }

        if runs.count == 2 {
            let gap = runs[1].start - runs[0].end
            let minimumGap = max(4, Int((Double(inkBounds.height) * Geometry.minimumSplitGapRatio).rounded(.up)))
            guard gap >= minimumGap else { return .ambiguous }
        } else if isLikelyTouchingPair(groupBounds[0], in: inkBounds) {
            return .ambiguous
        }

        let segments = groupBounds.compactMap { group in
            normalizedSegment(from: image, bounds: group)
        }
        guard segments.count == groupBounds.count else { return .ambiguous }
        return .digits(segments)
    }

    private static func meaningfulMask(in raster: InkRaster) -> [Bool] {
        let candidate = raster.pixels.map { $0 < Geometry.inkPixelThreshold }
        var visited = [Bool](repeating: false, count: candidate.count)
        var meaningful = [Bool](repeating: false, count: candidate.count)
        var queue: [Int] = []
        let minimumArea = max(
            Geometry.minimumComponentArea,
            Int((Double(raster.width * raster.height) * Geometry.minimumComponentAreaRatio).rounded())
        )

        func component(startingAt start: Int) -> [Int] {
            visited[start] = true
            queue.removeAll(keepingCapacity: true)
            queue.append(start)
            var head = 0

            while head < queue.count {
                let index = queue[head]
                head += 1
                let x = index % raster.width
                let y = index / raster.width

                for neighborY in max(0, y - 1)...min(raster.height - 1, y + 1) {
                    for neighborX in max(0, x - 1)...min(raster.width - 1, x + 1) {
                        let neighbor = neighborY * raster.width + neighborX
                        guard candidate[neighbor], !visited[neighbor] else { continue }
                        visited[neighbor] = true
                        queue.append(neighbor)
                    }
                }
            }
            return queue
        }

        for start in candidate.indices where candidate[start] && !visited[start] {
            let componentPixels = component(startingAt: start)
            guard componentPixels.count >= minimumArea else { continue }
            for index in componentPixels {
                meaningful[index] = true
            }
        }
        return meaningful
    }

    private static func occupiedRuns(
        in mask: [Bool],
        raster: InkRaster,
        bounds: InkBounds
    ) -> [ColumnRun] {
        var runs: [ColumnRun] = []
        var start: Int?

        for x in bounds.minX..<bounds.maxX {
            var occupied = false
            for y in bounds.minY..<bounds.maxY where mask[y * raster.width + x] {
                occupied = true
                break
            }
            if occupied {
                if start == nil { start = x }
            } else if let runStart = start {
                runs.append(ColumnRun(start: runStart, end: x))
                start = nil
            }
        }
        if let start {
            runs.append(ColumnRun(start: start, end: bounds.maxX))
        }
        return runs
    }

    private static func mergeSmallGaps(in runs: [ColumnRun], maximumGap: Int) -> [ColumnRun] {
        var merged: [ColumnRun] = []
        for run in runs {
            guard let previous = merged.last else {
                merged.append(run)
                continue
            }
            if run.start - previous.end <= maximumGap {
                merged[merged.count - 1] = ColumnRun(start: previous.start, end: run.end)
            } else {
                merged.append(run)
            }
        }
        return merged
    }

    private static func isPlausibleGlyph(_ glyph: InkBounds, in overall: InkBounds) -> Bool {
        let heightRatio = Double(glyph.height) / Double(overall.height)
        let aspectRatio = Double(glyph.width) / Double(glyph.height)
        return heightRatio >= Geometry.minimumGlyphHeightRatio
            && aspectRatio <= Geometry.maximumGlyphAspectRatio
    }

    private static func isLikelyTouchingPair(_ glyph: InkBounds, in overall: InkBounds) -> Bool {
        let aspectRatio = Double(glyph.width) / Double(glyph.height)
        return aspectRatio > Geometry.maximumSingleGlyphAspectRatio
            && Double(glyph.width) >= Double(overall.height) * Geometry.minimumTouchingWidthRatio
    }

    private static func bounds(
        of mask: [Bool],
        width: Int,
        height: Int,
        xRange: Range<Int>? = nil,
        yRange: Range<Int>? = nil
    ) -> InkBounds? {
        let minX = max(0, xRange?.lowerBound ?? 0)
        let maxX = min(width, xRange?.upperBound ?? width)
        let minY = max(0, yRange?.lowerBound ?? 0)
        let maxY = min(height, yRange?.upperBound ?? height)
        guard minX < maxX, minY < maxY else { return nil }

        var result: InkBounds?
        for y in minY..<maxY {
            for x in minX..<maxX where mask[y * width + x] {
                if let current = result {
                    result = InkBounds(
                        minX: min(current.minX, x),
                        maxX: max(current.maxX, x + 1),
                        minY: min(current.minY, y),
                        maxY: max(current.maxY, y + 1)
                    )
                } else {
                    result = InkBounds(minX: x, maxX: x + 1, minY: y, maxY: y + 1)
                }
            }
        }
        return result
    }

    private static func normalizedSegment(from image: CGImage, bounds: InkBounds) -> CGImage? {
        let padding = max(2, Int((Double(bounds.height) * Geometry.segmentPaddingRatio).rounded(.up)))
        let x = max(0, bounds.minX - padding)
        let y = max(0, bounds.minY - padding)
        let maxX = min(image.width, bounds.maxX + padding)
        let maxY = min(image.height, bounds.maxY + padding)
        guard x < maxX, y < maxY else { return nil }

        guard let crop = image.cropping(to: CGRect(
            x: CGFloat(x),
            y: CGFloat(y),
            width: CGFloat(maxX - x),
            height: CGFloat(maxY - y)
        )) else {
            return nil
        }

        // Match the spike's model input size while preserving production
        // black-on-white polarity and each group's aspect ratio.
        let targetDimension = Geometry.normalizedDimension
        var pixels = [UInt8](repeating: 255, count: targetDimension * targetDimension)
        let rendered = pixels.withUnsafeMutableBytes { buffer -> CGImage? in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: targetDimension,
                height: targetDimension,
                bitsPerComponent: 8,
                bytesPerRow: targetDimension,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return nil }

            context.setFillColor(gray: 1, alpha: 1)
            context.fill(CGRect(
                x: 0,
                y: 0,
                width: CGFloat(targetDimension),
                height: CGFloat(targetDimension)
            ))
            let contentDimension = CGFloat(targetDimension - 4)
            let scale = min(
                contentDimension / CGFloat(max(crop.width, 1)),
                contentDimension / CGFloat(max(crop.height, 1))
            )
            let drawSize = CGSize(
                width: CGFloat(crop.width) * scale,
                height: CGFloat(crop.height) * scale
            )
            let drawRect = CGRect(
                x: (CGFloat(targetDimension) - drawSize.width) / 2,
                y: (CGFloat(targetDimension) - drawSize.height) / 2,
                width: drawSize.width,
                height: drawSize.height
            )
            context.saveGState()
            context.translateBy(x: 0, y: CGFloat(targetDimension))
            context.scaleBy(x: 1, y: -1)
            context.interpolationQuality = .high
            context.draw(crop, in: drawRect)
            context.restoreGState()
            return context.makeImage()
        }
        return rendered
    }

    private struct InkRaster {
        let pixels: [UInt8]
        let width: Int
        let height: Int

        init?(image: CGImage) {
            guard image.width > 0, image.height > 0 else { return nil }
            let width = image.width
            let height = image.height
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
                context.fill(CGRect(
                    x: 0,
                    y: 0,
                    width: CGFloat(width),
                    height: CGFloat(height)
                ))
                context.saveGState()
                context.translateBy(x: 0, y: CGFloat(height))
                context.scaleBy(x: 1, y: -1)
                context.interpolationQuality = .medium
                context.draw(image, in: CGRect(
                    x: 0,
                    y: 0,
                    width: CGFloat(width),
                    height: CGFloat(height)
                ))
                context.restoreGState()
                return true
            }
            guard rendered else { return nil }
            self.pixels = pixels
            self.width = width
            self.height = height
        }
    }

    private struct InkBounds {
        let minX: Int
        let maxX: Int
        let minY: Int
        let maxY: Int

        var width: Int { maxX - minX }
        var height: Int { maxY - minY }
    }

    private struct ColumnRun {
        let start: Int
        let end: Int
    }
}

private enum Geometry {
    // Capture uses black ink on white. Keep antialiased stroke cores while
    // dropping isolated marks through the component-area floor below.
    static let inkPixelThreshold: UInt8 = 180
    static let minimumComponentArea = 12
    static let minimumComponentAreaRatio = 0.0002
    static let internalGapRatio = 0.08
    static let minimumSplitGapRatio = 0.12
    static let minimumGlyphHeightRatio = 0.45
    static let maximumGlyphAspectRatio = 1.25
    static let maximumSingleGlyphAspectRatio = 1.0
    static let minimumTouchingWidthRatio = 0.90
    static let segmentPaddingRatio = 0.02
    static let normalizedDimension = 28
}
