import XCTest
@testable import ScoreKeeper

final class ScoreRecognizerTests: XCTestCase {
    func testSingleZeroFragmentIsGenuineZero() {
        assertSuccess(
            ScoreRecognizer.interpret(fragments: [fragment("0")]),
            value: 0,
            confidence: 0.9
        )
    }

    func testFragmentsAreReorderedLeftToRightByMinX() {
        assertSuccess(
            ScoreRecognizer.interpret(fragments: [
                fragment("5", minX: 0.8),
                fragment("1", minX: 0.1),
            ]),
            value: 15,
            confidence: 0.9
        )
    }

    func testFragmentsAlreadyInMinXOrderJoinAsWritten() {
        assertSuccess(
            ScoreRecognizer.interpret(fragments: [
                fragment("1", minX: 0.1),
                fragment("5", minX: 0.4),
            ]),
            value: 15,
            confidence: 0.9
        )
    }

    func testCombinedFragmentsAbove99AreUnreadable() {
        XCTAssertEqual(
            ScoreRecognizer.interpret(fragments: [
                fragment("12", minX: 0.1),
                fragment("4", minX: 0.6),
            ]),
            .unreadable
        )
    }

    func testMinusFragmentAloneIsUnreadable() {
        XCTAssertEqual(
            ScoreRecognizer.interpret(fragments: [fragment("-3")]),
            .unreadable
        )
    }

    func testASCIIminusFragmentMakesCompleteReadingUnreadable() {
        XCTAssertEqual(
            ScoreRecognizer.interpret(fragments: [
                fragment("-3", minX: 0.1),
                fragment("4", minX: 0.5),
            ]),
            .unreadable
        )
    }

    func testUnicodeMinusFragmentMakesCompleteReadingUnreadable() {
        XCTAssertEqual(
            ScoreRecognizer.interpret(fragments: [
                fragment("−3", minX: 0.1),
                fragment("4", minX: 0.5),
            ]),
            .unreadable
        )
    }

    func testJunkOnlyFragmentsAreUnreadable() {
        XCTAssertEqual(
            ScoreRecognizer.interpret(fragments: [
                fragment("a", minX: 0.1),
                fragment("b", minX: 0.4),
            ]),
            .unreadable
        )
    }

    func testMixedAlphanumericFragmentIsUnreadable() {
        XCTAssertEqual(
            ScoreRecognizer.interpret(fragments: [fragment("1a2")]),
            .unreadable
        )
    }

    func testNoFragmentsIsUnreadable() {
        XCTAssertEqual(ScoreRecognizer.interpret(fragments: []), .unreadable)
    }

    func testFragmentBelowConfidenceThresholdIsRejected() {
        XCTAssertEqual(
            ScoreRecognizer.interpret(fragments: [fragment("7", confidence: 0.2)]),
            .unreadable
        )
    }

    func testLowConfidenceFragmentExcludedFromValueAndAverage() {
        assertSuccess(
            ScoreRecognizer.interpret(fragments: [
                fragment("3", minX: 0.1, confidence: 0.2),
                fragment("5", minX: 0.5, confidence: 0.8),
            ]),
            value: 5,
            confidence: 0.8
        )
    }

    func testValueAbove99IsUnreadable() {
        XCTAssertEqual(
            ScoreRecognizer.interpret(fragments: [fragment("99999")]),
            .unreadable
        )
    }

    func testOverflowingDigitStringIsUnreadable() {
        XCTAssertEqual(
            ScoreRecognizer.interpret(fragments: [fragment(String(repeating: "9", count: 30))]),
            .unreadable
        )
    }

    func testEmptyDigitFragmentIsSkipped() {
        assertSuccess(
            ScoreRecognizer.interpret(fragments: [
                fragment("", minX: 0.1),
                fragment("4", minX: 0.5),
            ]),
            value: 4,
            confidence: 0.9
        )
    }

    func testOnlyEmptyDigitFragmentsAreUnreadable() {
        XCTAssertEqual(
            ScoreRecognizer.interpret(fragments: [fragment(""), fragment("", minX: 0.5)]),
            .unreadable
        )
    }

    func testConfidenceIsAverageOfAcceptedFragments() {
        assertSuccess(
            ScoreRecognizer.interpret(fragments: [
                fragment("1", minX: 0.1, confidence: 0.8),
                fragment("2", minX: 0.5, confidence: 0.6),
            ]),
            value: 12,
            confidence: 0.7
        )
    }

    func testThresholdConstant() {
        XCTAssertEqual(ScoreRecognizer.defaultConfidenceThreshold, 0.35, accuracy: 0.0001)
    }

    func testVisionLowercaseOIsNotConvertedToZero() {
        XCTAssertNil(ScoreRecognizer.normalizedDigits(from: "o"))
    }

    func testVisionOneLikeLettersAndPunctuationAreNotConvertedToOne() {
        for candidate in ["I", "l", "|"] {
            XCTAssertNil(ScoreRecognizer.normalizedDigits(from: candidate))
        }
    }

    func testUnrelatedLettersAreNotSilentlyConvertedToDigits() {
        XCTAssertNil(ScoreRecognizer.normalizedDigits(from: "score"))
    }

    private func fragment(
        _ digits: String,
        minX: CGFloat = 0,
        confidence: Double = 0.9
    ) -> ScoreRecognitionFragment {
        ScoreRecognitionFragment(digits: digits, minX: minX, confidence: confidence)
    }

    private func assertSuccess(
        _ result: ScoreRecognitionResult,
        value: Int,
        confidence: Double,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case let .success(actualValue, actualConfidence) = result else {
            XCTFail("Expected .success, got \(result)", file: file, line: line)
            return
        }
        XCTAssertEqual(actualValue, value, file: file, line: line)
        XCTAssertEqual(actualConfidence, confidence, accuracy: 0.0001, file: file, line: line)
    }
}
