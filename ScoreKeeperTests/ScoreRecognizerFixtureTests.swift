import Foundation
import XCTest
import Vision
@testable import ScoreKeeper

@MainActor
final class ScoreRecognizerFixtureTests: XCTestCase {
    func testDrawnZeroIsCorrectOrUnreadable() async {
        await verifyDigitFixtureIsCorrectOrUnreadable("0", expected: 0)
    }

    func testSegmentedThinZeroIsRecognizedExactly() async {
        let result = await ScoreRecognizer.recognize(ScoreRecognitionFixtures.drawSegmentedThinZero())
        guard case let .success(value, confidence) = result else {
            XCTFail("segmented thin zero expected success, got \(result)")
            return
        }
        XCTAssertEqual(value, 0)
        XCTAssertGreaterThan(confidence, 0)
    }

    func testDrawnOneIsCorrectOrUnreadable() async {
        await verifyDigitFixtureIsCorrectOrUnreadable("1", expected: 1)
    }

    func testDrawnTwoIsRecognizedExactly() async {
        await verifyDigitFixture("2", expected: 2)
    }

    func testDrawnSevenIsRecognizedExactly() async {
        await verifyDigitFixture("7", expected: 7)
    }

    func testDrawnEightIsRecognizedExactly() async {
        await verifyDigitFixture("8", expected: 8)
    }

    func testDrawnTwelveIsRecognizedExactly() async {
        await verifyDigitFixture("12", expected: 12)
    }

    func testDrawnTwentyFiveIsRecognizedExactly() async {
        await verifyDigitFixture("25", expected: 25)
    }

    func testDrawnFiftyIsRecognizedExactly() async {
        await verifyDigitFixture("50", expected: 50)
    }

    func testDrawnNinetyNineIsRecognizedExactly() async {
        await verifyDigitFixture("99", expected: 99)
    }

    func testDrawnOneHundredFiveIsUnreadable() async {
        await verifyOutOfRangeFixtureIsUnreadable("105")
    }

    func testDrawnTwoHundredFiftyIsUnreadable() async {
        await verifyOutOfRangeFixtureIsUnreadable("250")
    }

    func testSmallOffsetOneHundredFiveIsUnreadable() async {
        await verifyOutOfRangeFixtureIsUnreadable("105", scale: 0.64, offset: CGPoint(x: -112, y: 16))
    }

    func testLargeOffsetTwentyFiveIsRecognizedExactly() async {
        await verifyDigitFixture("25", expected: 25, scale: 1.18, offset: CGPoint(x: 76, y: -10))
    }

    func testBlankFixtureNeverSucceeds() async {
        for level in recognitionLevels {
            assertFailedRecognition(
                await ScoreRecognizer.recognize(ScoreRecognitionFixtures.drawBlank(), recognitionLevel: level),
                fixture: "blank",
                level: level
            )
        }
    }

    func testScribbleFixtureNeverSucceeds() async {
        for level in recognitionLevels {
            assertFailedRecognition(
                await ScoreRecognizer.recognize(ScoreRecognitionFixtures.drawScribble(), recognitionLevel: level),
                fixture: "scribble",
                level: level
            )
        }
    }

    func testNegativeFixtureIsNeverReadAsPositive() async {
        for level in recognitionLevels {
            let result = await ScoreRecognizer.recognize(
                ScoreRecognitionFixtures.drawNegative("3"),
                recognitionLevel: level
            )
            if case let .success(value, _) = result {
                XCTFail("minus fixture was interpreted as positive value \(value) at level \(levelName(level))")
            }
            assertFailedRecognition(result, fixture: "negative-3", level: level)
        }
    }

    func testJunkFixtureNeverSucceeds() async {
        for level in recognitionLevels {
            assertFailedRecognition(
                await ScoreRecognizer.recognize(ScoreRecognitionFixtures.drawJunk(), recognitionLevel: level),
                fixture: "junk",
                level: level
            )
        }
    }

    func testPhantomZeroIsImpossible() async {
        for level in recognitionLevels {
            for fixture in ScoreRecognitionFixtures.allFixtures() {
                let result = await ScoreRecognizer.recognize(fixture.image, recognitionLevel: level)
                guard case let .success(value, _) = result else { continue }
                if fixture.allowsSuccessZero {
                    XCTAssertEqual(
                        value,
                        0,
                        "fixture \(fixture.name) at level \(levelName(level)) should read as the literal zero"
                    )
                } else {
                    XCTAssertNotEqual(
                        value,
                        0,
                        "phantom zero: fixture \(fixture.name) produced success(0) at level \(levelName(level))"
                    )
                }
            }
        }
    }

    func testLeadingMinusDetectorFindsUnsupportedNegativeScore() {
        XCTAssertTrue(ScoreRecognizer.containsLeadingMinus(in: ScoreRecognitionFixtures.drawNegative("3")))
    }

    func testLeadingMinusDetectorFindsShortUnsupportedNegativeScore() {
        XCTAssertTrue(ScoreRecognizer.containsLeadingMinus(in: ScoreRecognitionFixtures.drawShortNegative("3")))
    }

    func testLeadingMinusDetectorAllowsPositiveDigitCorpus() {
        for fixture in ScoreRecognitionFixtures.allFixtures() where fixture.name.hasPrefix("digits-") {
            XCTAssertFalse(
                ScoreRecognizer.containsLeadingMinus(in: fixture.image),
                "positive fixture \(fixture.name) looked like a negative score"
            )
        }
    }

    func testClosedZeroDetectorAcceptsSegmentedThinZero() {
        XCTAssertTrue(ScoreRecognizer.looksLikeClosedZero(in: ScoreRecognitionFixtures.drawSegmentedThinZero()))
    }

    func testClosedZeroDetectorRejectsNonzeroDigitCorpus() {
        for fixture in ScoreRecognitionFixtures.allFixtures()
            where fixture.name.hasPrefix("digits-") && !fixture.allowsSuccessZero {
            XCTAssertFalse(
                ScoreRecognizer.looksLikeClosedZero(in: fixture.image),
                "nonzero fixture \(fixture.name) looked like zero"
            )
        }
    }

    func testApprovedRecordingFixtureManifestMatchesBundledFixtures() throws {
        let object = try JSONSerialization.jsonObject(with: ScoreRecognitionFixtures.approvedFixtureManifestData())
        let manifest = try XCTUnwrap(object as? [String: Any])
        let cases = try XCTUnwrap(manifest["fixtures"] as? [[String: Any]])
        let expectedNames = Set(ScoreRecognitionFixtures.approvedRecordingFixtures().map(\.name))
        let manifestNames = Set(cases.compactMap { $0["name"] as? String })

        XCTAssertEqual(manifestNames, expectedNames)
        XCTAssertEqual(cases.count, expectedNames.count)
        for fixture in ScoreRecognitionFixtures.approvedRecordingFixtures() {
            XCTAssertNotNil(fixture.image.cgImage, "Missing image for \(fixture.name)")
            let manifestCase = cases.first { $0["name"] as? String == fixture.name }
            XCTAssertEqual(manifestCase?["file"] as? String, "\(fixture.name).png")
            XCTAssertEqual(manifestCase?["expected"] as? String, fixture.expected)
            XCTAssertEqual(manifestCase?["kind"] as? String, fixture.kind)
            let expectedSHA = try XCTUnwrap(manifestCase?["sha256"] as? String)
            XCTAssertEqual(expectedSHA.count, 64, "Malformed fixture hash: \(fixture.name)")
        }
    }

    func testRecordingThreeIsNeverAcceptedAsZero() async {
        let result = await ScoreRecognizer.recognize(ScoreRecognitionFixtures.recordingFixture(named: "recording-3"))
        if case let .success(value, _) = result {
            XCTAssertNotEqual(value, 0, "Recording-style 3 was accepted as zero")
        }
    }

    func testCrossedSevenIsNeverAcceptedAsOne() async {
        let result = await ScoreRecognizer.recognize(ScoreRecognitionFixtures.recordingFixture(named: "recording-crossed-7"))
        if case let .success(value, _) = result {
            XCTAssertNotEqual(value, 1, "Crossed recording-style 7 was accepted as one")
        }
    }

    func testRecordingTwoIsCorrectOrUnreadable() async {
        let result = await ScoreRecognizer.recognize(ScoreRecognitionFixtures.recordingFixture(named: "recording-2"))
        switch result {
        case let .success(value, _):
            XCTAssertEqual(value, 2, "Recording-style 2 was accepted as the wrong value")
        case .unreadable, .error:
            break
        case .noInk:
            XCTFail("Recording-style 2 was reported as no ink")
        }
    }

    func testRecordingNineAndOneAreCorrectOrUnreadable() async {
        await assertCorrectOrUnreadable(9, fixtureName: "recording-9")
        await assertCorrectOrUnreadable(1, fixtureName: "recording-1")
    }

    func testScribbleNeverReturnsSuccess() async {
        let result = await ScoreRecognizer.recognize(ScoreRecognitionFixtures.drawScribble())
        if case let .success(value, _) = result {
            XCTFail("Scribble was accepted as \(value)")
        }
    }

    private var recognitionLevels: [VNRequestTextRecognitionLevel] {
        [.accurate, .fast]
    }

    private func verifyDigitFixture(
        _ digits: String,
        expected: Int,
        scale: CGFloat = 1,
        offset: CGPoint = .zero,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let image = ScoreRecognitionFixtures.drawDigits(digits, scale: scale, offset: offset)

        let result = await ScoreRecognizer.recognize(image)
        guard case let .success(value, confidence) = result else {
            XCTFail("drawDigits(\"\(digits)\") expected success, got \(result)", file: file, line: line)
            return
        }
        XCTAssertEqual(value, expected, "drawDigits(\"\(digits)\") misread", file: file, line: line)
        XCTAssertGreaterThan(confidence, 0, "drawDigits(\"\(digits)\") carried no confidence", file: file, line: line)
    }

    private func verifyOutOfRangeFixtureIsUnreadable(
        _ digits: String,
        scale: CGFloat = 1,
        offset: CGPoint = .zero,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let result = await ScoreRecognizer.recognize(
            ScoreRecognitionFixtures.drawDigits(digits, scale: scale, offset: offset)
        )
        switch result {
        case let .success(value, _):
            XCTFail("Out-of-range drawDigits(\"\(digits)\") was accepted as \(value)", file: file, line: line)
        case .unreadable, .error:
            break
        case .noInk:
            XCTFail("Out-of-range drawDigits(\"\(digits)\") was reported as no ink", file: file, line: line)
        }
    }

    private func verifyDigitFixtureIsCorrectOrUnreadable(
        _ digits: String,
        expected: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let result = await ScoreRecognizer.recognize(ScoreRecognitionFixtures.drawDigits(digits))
        switch result {
        case let .success(value, confidence):
            XCTAssertEqual(value, expected, "drawDigits(\"\(digits)\") misread", file: file, line: line)
            XCTAssertGreaterThan(confidence, 0, file: file, line: line)
        case .unreadable, .error:
            break
        case .noInk:
            XCTFail("drawDigits(\"\(digits)\") was reported as no ink", file: file, line: line)
        }
    }

    private func assertFailedRecognition(
        _ result: ScoreRecognitionResult,
        fixture: String,
        level: VNRequestTextRecognitionLevel,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        switch result {
        case let .success(value, _):
            XCTFail("\(fixture) at level \(levelName(level)) expected failure, got success(\(value))", file: file, line: line)
        case .unreadable, .error:
            break
        case .noInk:
            XCTFail("\(fixture) at level \(levelName(level)): recognize() must not report .noInk for a rendered image", file: file, line: line)
        }
    }

    private func levelName(_ level: VNRequestTextRecognitionLevel) -> String {
        level == .accurate ? "accurate" : "fast"
    }

    private func assertRecognizedValue(
        _ expected: Int,
        fixtureName: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let result = await ScoreRecognizer.recognize(ScoreRecognitionFixtures.recordingFixture(named: fixtureName))
        guard case let .success(value, _) = result else {
            XCTFail("\(fixtureName) expected success(\(expected)), got \(result)", file: file, line: line)
            return
        }
        XCTAssertEqual(value, expected, file: file, line: line)
    }

    private func assertCorrectOrUnreadable(
        _ expected: Int,
        fixtureName: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let result = await ScoreRecognizer.recognize(ScoreRecognitionFixtures.recordingFixture(named: fixtureName))
        switch result {
        case let .success(value, _):
            XCTAssertEqual(value, expected, file: file, line: line)
        case .unreadable, .error:
            break
        case .noInk:
            XCTFail("\(fixtureName) was reported as no ink", file: file, line: line)
        }
    }
}
