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
                fragment("0", minX: 0.4),
            ]),
            value: 105,
            confidence: 0.9
        )
    }

    func testFragmentsAlreadyInMinXOrderJoinAsWritten() {
        assertSuccess(
            ScoreRecognizer.interpret(fragments: [
                fragment("1", minX: 0.1),
                fragment("0", minX: 0.4),
                fragment("5", minX: 0.8),
            ]),
            value: 105,
            confidence: 0.9
        )
    }

    func testMultiCharacterFragmentStaysWhole() {
        assertSuccess(
            ScoreRecognizer.interpret(fragments: [
                fragment("12", minX: 0.1),
                fragment("4", minX: 0.6),
            ]),
            value: 124,
            confidence: 0.9
        )
    }

    func testMinusFragmentAloneIsUnreadable() {
        XCTAssertEqual(
            ScoreRecognizer.interpret(fragments: [fragment("-3")]),
            .unreadable
        )
    }

    func testMinusFragmentIsDiscardedWhenCleanFragmentExists() {
        assertSuccess(
            ScoreRecognizer.interpret(fragments: [
                fragment("-3", minX: 0.1),
                fragment("4", minX: 0.5),
            ]),
            value: 4,
            confidence: 0.9
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

    func testJunkWithinFragmentIsStripped() {
        assertSuccess(
            ScoreRecognizer.interpret(fragments: [fragment("1a2")]),
            value: 12,
            confidence: 0.9
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

    func testValueIsCappedAt9999() {
        assertSuccess(
            ScoreRecognizer.interpret(fragments: [fragment("99999")]),
            value: 9999,
            confidence: 0.9
        )
    }

    func testOverflowingDigitStringIsCappedAt9999() {
        assertSuccess(
            ScoreRecognizer.interpret(fragments: [fragment(String(repeating: "9", count: 30))]),
            value: 9999,
            confidence: 0.9
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
