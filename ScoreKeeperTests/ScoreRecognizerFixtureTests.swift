import XCTest
import Vision
@testable import ScoreKeeper

@MainActor
final class ScoreRecognizerFixtureTests: XCTestCase {
    func testDrawnZeroIsRecognizedExactly() async {
        await verifyDigitFixture("0", expected: 0)
    }

    func testDrawnSevenIsRecognizedExactly() async {
        await verifyDigitFixture("7", expected: 7)
    }

    func testDrawnTwentyFiveIsRecognizedExactly() async {
        await verifyDigitFixture("25", expected: 25)
    }

    func testDrawnOneHundredFiveIsRecognizedExactly() async {
        await verifyDigitFixture("105", expected: 105)
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

    func testDumpCurrentFixtureImages() throws {
        let root = URL(fileURLWithPath: "/Users/prateekranka/Cowork/ScoreKeeper-worktrees/app-dev-pipcount/.score-recognition-evidence/current-dumps")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        for fixture in ScoreRecognitionFixtures.allFixtures() {
            try fixture.image.pngData()?.write(to: root.appendingPathComponent("\(fixture.name).png"))
        }
    }

    func testDumpVisionCandidatesForInvestigation() throws {
        for fixture in ScoreRecognitionFixtures.allFixtures() where fixture.name.hasPrefix("digits-") {
            guard let cgImage = fixture.image.cgImage else { continue }
            let request = VNRecognizeTextRequest { request, error in
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                print("VISION fixture=\(fixture.name) error=\(String(describing: error)) observations=\(observations.count)")
                for (index, observation) in observations.enumerated() {
                    let candidates = observation.topCandidates(3).map { "\($0.string):\($0.confidence)" }.joined(separator: " | ")
                    print("VISION fixture=\(fixture.name) observation=\(index) box=\(observation.boundingBox) candidates=\(candidates)")
                }
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
        }
    }

    private var recognitionLevels: [VNRequestTextRecognitionLevel] {
        [.accurate, .fast]
    }

    private func verifyDigitFixture(
        _ digits: String,
        expected: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let image = ScoreRecognitionFixtures.drawDigits(digits)

        let accurate = await ScoreRecognizer.recognize(image, recognitionLevel: .accurate)
        guard case let .success(value, confidence) = accurate else {
            XCTFail("drawDigits(\"\(digits)\") at .accurate expected success, got \(accurate)", file: file, line: line)
            return
        }
        XCTAssertEqual(value, expected, "drawDigits(\"\(digits)\") misread at .accurate", file: file, line: line)
        XCTAssertGreaterThan(confidence, 0, "drawDigits(\"\(digits)\") carried no confidence", file: file, line: line)

        let fast = await ScoreRecognizer.recognize(image, recognitionLevel: .fast)
        print("ScoreRecognizerFixtureTests: .fast outcome for \"\(digits)\" -> \(fast)")
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
}
