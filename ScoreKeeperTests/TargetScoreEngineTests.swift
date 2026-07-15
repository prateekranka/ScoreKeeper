import XCTest
@testable import ScoreKeeper

final class TargetScoreEngineTests: XCTestCase {
    private let engine = GenericEngine()

    func testTargetScoreConfigurationAcceptsEmptyAndPositiveWholeNumbers() {
        XCTAssertNil(TargetScoreConfiguration.validationMessage(for: ""))
        XCTAssertNil(TargetScoreConfiguration.validationMessage(for: "  "))
        XCTAssertEqual(TargetScoreConfiguration.value(from: " 25 "), 25)
        XCTAssertNil(TargetScoreConfiguration.validationMessage(for: "25"))
    }

    func testTargetScoreConfigurationRejectsNonPositiveAndNonIntegerValues() {
        for invalidValue in ["0", "-1", "1.5", "hello"] {
            XCTAssertNotNil(TargetScoreConfiguration.validationMessage(for: invalidValue), invalidValue)
            XCTAssertNil(TargetScoreConfiguration.value(from: invalidValue), invalidValue)
        }
    }

    func testTargetGameIsNeverCompleteAtStartForHighestAndLowestModes() {
        for condition in [WinCondition.highestScore, .lowestScore] {
            let session = makeSession(targetScore: 10, winCondition: condition)

            XCTAssertFalse(engine.isGameOver(session: session))
            XCTAssertFalse(session.isComplete)
        }
    }

    func testNonQualifyingSubmittedRoundDoesNotCompleteGame() {
        let session = makeSession(targetScore: 10, winCondition: .highestScore)
        appendRound(to: session, scores: [4, 3])

        XCTAssertFalse(engine.isGameOver(session: session))
        XCTAssertEqual(session.sortedRounds.count, 1)
    }

    func testQualifyingRoundCompletesHighestScoreTargetGame() {
        let session = makeSession(targetScore: 10, winCondition: .highestScore)
        appendRound(to: session, scores: [10, 4])

        XCTAssertTrue(engine.isGameOver(session: session))
        XCTAssertEqual(engine.winners(session: session), [session.players[0].id])
    }

    func testQualifyingRoundCompletesLowestScoreTargetGameAndKeepsLowestWinner() {
        let session = makeSession(targetScore: 10, winCondition: .lowestScore)
        appendRound(to: session, scores: [12, 15])

        XCTAssertTrue(engine.isGameOver(session: session))
        XCTAssertEqual(engine.winners(session: session), [session.players[0].id])
    }

    func testLowestScoreTargetGamePreservesWinnerTies() {
        let session = makeSession(targetScore: 10, winCondition: .lowestScore)
        appendRound(to: session, scores: [12, 12])

        XCTAssertTrue(engine.isGameOver(session: session))
        XCTAssertEqual(Set(engine.winners(session: session)), Set(session.players.map(\.id)))
    }

    func testNoTargetGameRemainsManualOnlyUntilMarkedComplete() {
        let session = makeSession(targetScore: nil, winCondition: .highestScore)
        appendRound(to: session, scores: [100, 0])

        XCTAssertFalse(engine.isGameOver(session: session))

        session.isComplete = true
        XCTAssertTrue(engine.isGameOver(session: session))
    }

    func testTargetScoreIsRetainedWhenCreatingRematchConfiguration() {
        let original = makeSession(targetScore: 42, winCondition: .lowestScore)
        let rematch = GameSession(gameType: original.gameType)
        rematch.targetScore = original.targetScore
        rematch.winCondition = original.winCondition

        XCTAssertEqual(rematch.targetScore, 42)
        XCTAssertEqual(rematch.winCondition.rawValueString, "lowest")
    }

    private func makeSession(targetScore: Int?, winCondition: WinCondition) -> GameSession {
        let session = GameSession(gameType: .generic)
        session.targetScore = targetScore
        session.winCondition = winCondition

        let first = Player(name: "Alice", colorIndex: 0)
        first.session = session
        let second = Player(name: "Bob", colorIndex: 1)
        second.session = session
        session.players = [first, second]
        return session
    }

    private func appendRound(to session: GameSession, scores: [Int]) {
        let round = Round(roundNumber: session.currentRoundNumber)
        round.session = session

        for (index, player) in session.players.enumerated() {
            let entry = ScoreEntry(playerID: player.id, points: scores[index])
            entry.round = round
            round.entries.append(entry)
        }

        session.rounds.append(round)
    }
}
