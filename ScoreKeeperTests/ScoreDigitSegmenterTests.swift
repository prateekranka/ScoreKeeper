import XCTest
import UIKit
@testable import ScoreKeeper

@MainActor
final class ScoreDigitSegmenterTests: XCTestCase {
    func testBlankImageReturnsNoInk() {
        XCTAssertEqual(segmentation(for: ScoreRecognitionFixtures.drawBlank()), .noInk)
    }

    func testTinyNoiseReturnsNoInk() {
        XCTAssertEqual(segmentation(for: ScoreRecognitionFixtures.drawTinyNoise()), .noInk)
    }

    func testScribbleReturnsAmbiguous() {
        XCTAssertEqual(segmentation(for: ScoreRecognitionFixtures.drawScribble()), .ambiguous)
    }

    func testEverySyntheticSingleProducesOneNormalizedSegment() {
        for digit in 0...9 {
            assertSegmentCount(
                1,
                for: ScoreRecognitionFixtures.drawDigits(String(digit)),
                fixture: "synthetic-single-\(digit)"
            )
        }
    }

    func testEverySyntheticDoubleProducesTwoNormalizedSegments() {
        for value in 10...99 {
            assertSegmentCount(
                2,
                for: ScoreRecognitionFixtures.drawDigits(String(value)),
                fixture: "synthetic-double-\(value)"
            )
        }
    }

    func testDetachedCrossbarFourRemainsOneSegment() {
        assertSegmentCount(1, for: ScoreRecognitionFixtures.drawDetachedCrossbarFour(), fixture: "detached-crossbar-4")
    }

    func testTwoLoopEightRemainsOneSegment() {
        assertSegmentCount(1, for: ScoreRecognitionFixtures.drawDigits("8"), fixture: "two-loop-8")
    }

    func testCrossedSevenRemainsOneSegment() {
        assertSegmentCount(1, for: ScoreRecognitionFixtures.drawCrossedSeven(), fixture: "crossed-7")
    }

    func testNarrowElevenRemainsTwoSegments() {
        assertSegmentCount(2, for: ScoreRecognitionFixtures.drawDigits("11"), fixture: "narrow-11")
    }

    func testApprovedRecordingSinglesRemainOneSegment() {
        for fixture in ScoreRecognitionFixtures.recordingSingleFixtures() {
            assertSegmentCount(1, for: fixture.image, fixture: fixture.name)
        }
    }

    func testApprovedRecordingDoublesRemainTwoSegments() {
        for fixture in ScoreRecognitionFixtures.recordingDoubleFixtures() {
            assertSegmentCount(2, for: fixture.image, fixture: fixture.name)
        }
    }

    func testTouchingDigitsReturnAmbiguous() {
        XCTAssertEqual(segmentation(for: ScoreRecognitionFixtures.drawTouchingDigits()), .ambiguous)
    }

    func testMoreThanTwoGroupsReturnUnsupported() {
        XCTAssertEqual(segmentation(for: ScoreRecognitionFixtures.drawDigits("123")), .unsupported)
    }

    func testUnsupportedNegativeReturnsUnsupported() {
        XCTAssertEqual(segmentation(for: ScoreRecognitionFixtures.drawNegative("3")), .unsupported)
    }

    func testSegmentsAreNormalizedIndependently() {
        guard let image = ScoreRecognitionFixtures.drawDigits("25").cgImage else {
            XCTFail("Missing synthetic image")
            return
        }
        guard case let .digits(segments) = ScoreDigitSegmenter.segment(image) else {
            XCTFail("Expected two segments")
            return
        }

        XCTAssertEqual(segments.count, 2)
        for segment in segments {
            XCTAssertEqual(segment.width, 28)
            XCTAssertEqual(segment.height, 28)
        }
    }

    func testRepeatedSegmentationHasStableShape() {
        guard let image = ScoreRecognitionFixtures.drawDigits("37").cgImage else {
            XCTFail("Missing synthetic image")
            return
        }
        let first = segmentationShape(for: image)
        let second = segmentationShape(for: image)
        XCTAssertEqual(first, ["28x28", "28x28"])
        XCTAssertEqual(second, first)
    }

    private func segmentation(for image: UIImage) -> ScoreDigitSegmentation {
        guard let cgImage = image.cgImage else {
            XCTFail("Fixture has no CGImage")
            return .ambiguous
        }
        return ScoreDigitSegmenter.segment(cgImage)
    }

    private func assertSegmentCount(
        _ expectedCount: Int,
        for image: UIImage,
        fixture: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let cgImage = image.cgImage else {
            XCTFail("Fixture \(fixture) has no CGImage", file: file, line: line)
            return
        }
        guard case let .digits(segments) = ScoreDigitSegmenter.segment(cgImage) else {
            XCTFail("Fixture \(fixture) did not produce digit segments", file: file, line: line)
            return
        }
        XCTAssertEqual(segments.count, expectedCount, "Fixture \(fixture) had the wrong segment count", file: file, line: line)
        XCTAssertTrue(segments.allSatisfy { $0.width == 28 && $0.height == 28 }, "Fixture \(fixture) was not normalized", file: file, line: line)
    }

    private func segmentationShape(for image: CGImage) -> [String] {
        guard case let .digits(segments) = ScoreDigitSegmenter.segment(image) else { return [] }
        return segments.map { "\($0.width)x\($0.height)" }
    }
}
