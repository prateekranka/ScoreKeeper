import XCTest
import SwiftData
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

    func testPhase10ProgressionAndCompletionUseCompletedPlayerTieBreak() {
        let session = makeSession(gameType: .phase10, names: ["Alice", "Bob"])
        appendPhaseRound(to: session, phases: [3, 2], scores: [8, 1])
        appendPhaseRound(to: session, phases: [10, 4], scores: [7, 2])

        XCTAssertEqual(Phase10Engine().currentPhase(for: session.players[0].id, in: session), 10)
        XCTAssertTrue(Phase10Engine().isGameOver(session: session))
        XCTAssertEqual(Phase10Engine().winners(session: session), [session.players[0].id])

        let tie = makeSession(gameType: .phase10, names: ["Alice", "Bob"])
        appendPhaseRound(to: tie, phases: [10, 10], scores: [5, 5])
        XCTAssertEqual(Set(Phase10Engine().winners(session: tie)), Set(tie.players.map(\.id)))
    }

    func testPhase10FailedProgressChoosesBestProgressThenLowestPointsAndNoProgressHasNoWinner() {
        let session = makeSession(gameType: .phase10, names: ["Alice", "Bob", "Cara"])
        appendPhaseRound(to: session, phases: [2, 2, 1], scores: [9, 4, 0])
        XCTAssertEqual(Phase10Engine().winners(session: session), [session.players[1].id])

        let noProgress = makeSession(gameType: .phase10, names: ["Alice", "Bob"])
        appendPhaseRound(to: noProgress, phases: [0, 0], scores: [0, 0])
        XCTAssertTrue(Phase10Engine().winners(session: noProgress).isEmpty)
    }

    func testWhatsForDinnerLowestWinnerTieAndZeroScores() {
        let engine = WhatsForDinnerEngine()
        let session = makeSession(gameType: .whatsForDinner, names: ["Alice", "Bob", "Cara"])
        appendRound(to: session, scores: [4, 2, 2])
        XCTAssertEqual(Set(engine.winners(session: session)), Set([session.players[1].id, session.players[2].id]))

        let zero = makeSession(gameType: .whatsForDinner, names: ["Alice", "Bob"])
        appendRound(to: zero, scores: [0, 0])
        XCTAssertTrue(engine.winners(session: zero).isEmpty)
    }

    @MainActor
    func testStatsCalculatorReportsScoresRanksHeadToHeadByGameAndNoData() {
        let first = makeSession(gameType: .generic, names: ["Alice", "Bob"])
        appendRound(to: first, scores: [10, 5])
        let second = makeSession(gameType: .generic, names: ["Alice", "Bob"])
        appendRound(to: second, scores: [2, 5])
        let dinner = makeSession(gameType: .whatsForDinner, names: ["Alice", "Bob"])
        appendRound(to: dinner, scores: [1, 3])

        let stats = StatsCalculator.stats(for: "Alice", sessions: [first, second, dinner])
        XCTAssertEqual(stats.gamesPlayed, 3)
        XCTAssertEqual(stats.wins, 2)
        XCTAssertEqual(stats.bestRank, 1)
        XCTAssertEqual(stats.avgScore, 13.0 / 3.0, accuracy: 0.0001)
        XCTAssertEqual(StatsCalculator.stats(for: "Nobody", sessions: []).gamesPlayed, 0)
        XCTAssertEqual(StatsCalculator.stats(for: "Nobody", sessions: []).bestRank, 0)
        XCTAssertEqual(StatsCalculator.stats(for: "Nobody", sessions: []).avgScore, 0)

        let all = StatsCalculator.headToHead("Alice", vs: "Bob", sessions: [first, second, dinner])
        XCTAssertEqual(all.aWins, 2)
        XCTAssertEqual(all.bWins, 1)
        XCTAssertEqual(all.gamesTogether, 3)
        XCTAssertEqual(StatsCalculator.headToHeadByGameType("Alice", vs: "Bob", sessions: [first, second, dinner]).map(\.gameType), [.generic, .whatsForDinner])
        XCTAssertEqual(StatsCalculator.gamesBetween("Alice", and: "Bob", gameType: .generic, sessions: [first, second]).count, 2)
        XCTAssertTrue(StatsCalculator.headToHead("Alice", vs: "Nobody", sessions: []).gamesTogether == 0)
    }

    func testGameSessionUnknownRawValuesRecoverAndRoundOrderingDrivesNextRound() {
        let session = makeSession(targetScore: nil, winCondition: .highestScore)
        session.gameTypeRaw = "future-game"
        session.winConditionRaw = "future-condition"
        XCTAssertEqual(session.gameType, .generic)
        XCTAssertEqual(session.winCondition, .highestScore)

        session.rounds = [Round(roundNumber: 3), Round(roundNumber: 1)]
        XCTAssertEqual(session.sortedRounds.map(\.roundNumber), [1, 3])
        XCTAssertEqual(session.currentRoundNumber, 4)
    }

    func testInvalidPhaseMetadataIsIgnoredWithoutLosingValidProgress() {
        let session = makeSession(gameType: .phase10, names: ["Alice", "Bob"])
        let round = Round(roundNumber: 1)
        round.session = session
        let invalid = ScoreEntry(playerID: session.players[0].id, points: 4, metadata: "not-json")
        let valid = ScoreEntry(playerID: session.players[1].id, points: 2)
        valid.phase10Metadata = Phase10Metadata(phaseCompleted: 4, leftoverPoints: 2)
        invalid.round = round
        valid.round = round
        round.entries = [invalid, valid]
        session.rounds = [round]

        XCTAssertNil(invalid.phase10Metadata)
        XCTAssertEqual(Phase10Engine().currentPhase(for: session.players[0].id, in: session), 0)
        XCTAssertEqual(Phase10Engine().currentPhase(for: session.players[1].id, in: session), 4)
    }

    @MainActor
    func testInMemorySwiftDataPersistsRoundsAndCascadesSessionDeletion() throws {
        let container = try ModelContainer(
            for: GameSession.self, Player.self, Round.self, ScoreEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let session = makeSession(targetScore: 10, winCondition: .highestScore)
        appendRound(to: session, scores: [3, 1])
        context.insert(session)
        try context.save()

        XCTAssertEqual(try context.fetch(FetchDescriptor<GameSession>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Round>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ScoreEntry>()).count, 2)

        context.delete(session)
        try context.save()
        XCTAssertEqual(try context.fetch(FetchDescriptor<GameSession>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Player>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Round>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ScoreEntry>()).count, 0)
    }

    private func makeSession(targetScore: Int?, winCondition: WinCondition) -> GameSession {
        makeSession(gameType: .generic, names: ["Alice", "Bob"], targetScore: targetScore, winCondition: winCondition)
    }

    private func makeSession(gameType: GameType, names: [String], targetScore: Int? = nil, winCondition: WinCondition? = nil) -> GameSession {
        let session = GameSession(gameType: gameType)
        session.targetScore = targetScore
        if let winCondition { session.winCondition = winCondition }
        session.players = names.enumerated().map { index, name in
            let player = Player(name: name, colorIndex: index)
            player.session = session
            return player
        }
        return session
    }

    private func appendRound(to session: GameSession, scores: [Int]) {
        let round = Round(roundNumber: session.currentRoundNumber)
        round.session = session
        round.entries = session.players.enumerated().map { index, player in
            let entry = ScoreEntry(playerID: player.id, points: scores[index])
            entry.round = round
            return entry
        }
        session.rounds.append(round)
    }

    private func appendPhaseRound(to session: GameSession, phases: [Int], scores: [Int]) {
        let round = Round(roundNumber: session.currentRoundNumber)
        round.session = session
        round.entries = session.players.enumerated().map { index, player in
            let entry = ScoreEntry(playerID: player.id, points: scores[index])
            entry.phase10Metadata = Phase10Metadata(phaseCompleted: phases[index], leftoverPoints: scores[index])
            entry.round = round
            return entry
        }
        session.rounds.append(round)
    }
}
