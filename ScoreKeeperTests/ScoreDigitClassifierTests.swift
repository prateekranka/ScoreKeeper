import XCTest
@testable import ScoreKeeper

@MainActor
final class ScoreDigitClassifierTests: XCTestCase {
    private let acceptance = ScoreDigitAcceptancePolicy(
        minimumProbability: 0.80,
        minimumMargin: 0.20
    )

    func testPredictionExposesRunnerUpMargin() {
        let prediction = ScoreDigitPrediction(
            digit: 7,
            probability: 0.91,
            runnerUpProbability: 0.12
        )

        XCTAssertEqual(prediction.margin, 0.79, accuracy: 0.0001)
    }

    func testDigitInputRejectsMismatchedPixelCount() {
        XCTAssertNil(ScoreDigitInput(width: 28, height: 28, pixels: [0]))
    }

    func testDigitInputOwnsImmutablePixelValue() {
        var pixels = [UInt8](repeating: 255, count: 28 * 28)
        let input = ScoreDigitInput(pixels: pixels)
        pixels[0] = 0

        XCTAssertEqual(input?.pixels[0], 255)
    }


    func testInjectedClassifierCanRecognizeEveryDigitLabel() async {
        for digit in 0...9 {
            let classifier = RecordingClassifier(responses: [
                .success(ScoreDigitPrediction(
                    digit: digit,
                    probability: 0.95,
                    runnerUpProbability: 0.02
                )),
            ])

            let result = await ScoreRecognizer.recognize(
                segments: [pixelBuffer()],
                classifier: classifier,
                acceptance: acceptance
            )

            XCTAssertEqual(result, .success(value: digit, confidence: 0.95))
            XCTAssertEqual(classifier.callCount, 1)
        }
    }

    func testBlankSegmentsReturnNoInkWithoutInvokingClassifier() async {
        let classifier = RecordingClassifier(responses: [])

        let result = await ScoreRecognizer.recognize(
            segments: [],
            classifier: classifier,
            acceptance: acceptance
        )

        XCTAssertEqual(result, .noInk)
        XCTAssertEqual(classifier.callCount, 0)
    }

    func testMoreThanTwoSegmentsAreUnsupportedWithoutInvokingClassifier() async {
        let classifier = RecordingClassifier(responses: [])

        let result = await ScoreRecognizer.recognize(
            segments: [pixelBuffer(), pixelBuffer(), pixelBuffer()],
            classifier: classifier,
            acceptance: acceptance
        )

        XCTAssertEqual(result, .unreadable)
        XCTAssertEqual(classifier.callCount, 0)
    }

    func testInvalidAcceptancePolicyFailsClosedBeforeInvokingClassifier() async {
        let classifier = RecordingClassifier(responses: [
            .success(ScoreDigitPrediction(digit: 2, probability: 1, runnerUpProbability: 0)),
        ])
        let invalidPolicy = ScoreDigitAcceptancePolicy(
            minimumProbability: .nan,
            minimumMargin: 0.20
        )

        let result = await ScoreRecognizer.recognize(
            segments: [pixelBuffer()],
            classifier: classifier,
            acceptance: invalidPolicy
        )

        XCTAssertEqual(result, .error)
        XCTAssertEqual(classifier.callCount, 0)
    }

    func testRejectClassStopsTheWholeScore() async {
        let classifier = RecordingClassifier(responses: [
            .success(ScoreDigitPrediction(digit: 10, probability: 0.99, runnerUpProbability: 0.01)),
            .success(ScoreDigitPrediction(digit: 2, probability: 0.99, runnerUpProbability: 0.01)),
        ])

        let result = await ScoreRecognizer.recognize(
            segments: [pixelBuffer(), pixelBuffer()],
            classifier: classifier,
            acceptance: acceptance
        )

        XCTAssertEqual(result, .unreadable)
        XCTAssertEqual(classifier.callCount, 1)
    }

    func testLowProbabilityIsRejected() async {
        let classifier = RecordingClassifier(responses: [
            .success(ScoreDigitPrediction(digit: 3, probability: 0.79, runnerUpProbability: 0.02)),
        ])

        let result = await ScoreRecognizer.recognize(
            segments: [pixelBuffer()],
            classifier: classifier,
            acceptance: acceptance
        )

        XCTAssertEqual(result, .unreadable)
    }

    func testLowRunnerUpMarginIsRejected() async {
        let classifier = RecordingClassifier(responses: [
            .success(ScoreDigitPrediction(digit: 3, probability: 0.90, runnerUpProbability: 0.75)),
        ])

        let result = await ScoreRecognizer.recognize(
            segments: [pixelBuffer()],
            classifier: classifier,
            acceptance: acceptance
        )

        XCTAssertEqual(result, .unreadable)
    }

    func testClassifierFailureDoesNotProduceAValue() async {
        let classifier = RecordingClassifier(responses: [.failure])

        let result = await ScoreRecognizer.recognize(
            segments: [pixelBuffer()],
            classifier: classifier,
            acceptance: acceptance
        )

        XCTAssertEqual(result, .error)
    }

    func testImagePipelineRejectsBlankBeforeSegmenting() async {
        let classifier = RecordingClassifier(responses: [
            .success(ScoreDigitPrediction(digit: 0, probability: 0.99, runnerUpProbability: 0.01)),
        ])
        let segment = pixelBuffer()

        let result = await ScoreRecognizer.recognize(
            ScoreRecognitionFixtures.drawBlank(),
            segmenter: { _ in [segment] },
            classifier: classifier,
            acceptance: acceptance
        )

        XCTAssertEqual(result, .noInk)
        XCTAssertEqual(classifier.callCount, 0)
    }

    func testImagePipelineRejectsLeadingMinusBeforeClassification() async {
        let classifier = RecordingClassifier(responses: [
            .success(ScoreDigitPrediction(digit: 3, probability: 0.99, runnerUpProbability: 0.01)),
        ])
        let segment = pixelBuffer()

        let result = await ScoreRecognizer.recognize(
            ScoreRecognitionFixtures.drawNegative("3"),
            segmenter: { _ in [segment] },
            classifier: classifier,
            acceptance: acceptance
        )

        XCTAssertEqual(result, .unreadable)
        XCTAssertEqual(classifier.callCount, 0)
    }

    func testImagePipelineJoinsInjectedSegmentsInOrder() async {
        let classifier = RecordingClassifier(responses: [
            .success(ScoreDigitPrediction(digit: 1, probability: 0.91, runnerUpProbability: 0.02)),
            .success(ScoreDigitPrediction(digit: 2, probability: 0.87, runnerUpProbability: 0.03)),
        ])
        let segments = [pixelBuffer(), pixelBuffer()]

        let result = await ScoreRecognizer.recognize(
            ScoreRecognitionFixtures.drawDigits("12"),
            segmenter: { _ in segments },
            classifier: classifier,
            acceptance: acceptance
        )

        XCTAssertEqual(result, .success(value: 12, confidence: 0.87))
        XCTAssertEqual(classifier.callCount, 2)
    }

    private func pixelBuffer() -> ScoreDigitInput {
        guard let input = ScoreDigitInput(pixels: [UInt8](repeating: 255, count: 28 * 28)) else {
            fatalError("Test digit input could not be created")
        }
        return input
    }
}

private final class RecordingClassifier: ScoreDigitClassifying, @unchecked Sendable {
    enum Response {
        case success(ScoreDigitPrediction)
        case failure
    }

    private var responses: [Response]
    private(set) var callCount = 0

    init(responses: [Response]) {
        self.responses = responses
    }

    func classify(_ input: ScoreDigitInput) async throws -> ScoreDigitPrediction {
        callCount += 1
        guard !responses.isEmpty else { throw Failure.inference }

        switch responses.removeFirst() {
        case let .success(prediction):
            return prediction
        case .failure:
            throw Failure.inference
        }
    }

    private enum Failure: Error {
        case inference
    }
}
