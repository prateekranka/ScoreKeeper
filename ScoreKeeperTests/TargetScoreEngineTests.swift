import XCTest
import SwiftData
import SwiftUI
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

    func testPhase10StandingsRankProgressBeforePointsSoTheWinnerLeads() {
        let session = makeSession(gameType: .phase10, names: ["Alice", "Bob"])
        appendPhaseRound(to: session, phases: [1, 0], scores: [50, 0])

        let engine = Phase10Engine()
        XCTAssertEqual(engine.winners(session: session), [session.players[0].id])

        let ranked = engine.rankedPlayers(session: session)
        XCTAssertEqual(
            ranked.map(\.name),
            ["Alice", "Bob"],
            "A lower-progress zero-point player must not outrank the winner"
        )
        XCTAssertEqual(engine.rank(of: session.players[0], in: session), 1)
        XCTAssertEqual(engine.rank(of: session.players[1], in: session), 2)

        // Result rows and rank numbers stay in agreement with the winner.
        let standings = session.standings(using: engine)
        XCTAssertEqual(standings.first?.player.name, "Alice")
        XCTAssertTrue(standings.first?.isWinner == true)
    }

    func testPhase10CompletedPlayersOutrankHigherPointIncompleteProgress() {
        let session = makeSession(gameType: .phase10, names: ["Alice", "Bob"])
        appendPhaseRound(to: session, phases: [10, 9], scores: [80, 5])

        let engine = Phase10Engine()
        XCTAssertEqual(engine.winners(session: session), [session.players[0].id])
        XCTAssertEqual(engine.rankedPlayers(session: session).first?.name, "Alice")
        XCTAssertTrue(session.standings(using: engine).first?.isWinner == true)
    }

    func testTiedPlayersShareARankAndTheNextRankSkipsTheTie() {
        let session = makeSession(gameType: .whatsForDinner, names: ["Alice", "Bob", "Cara"])
        appendRound(to: session, scores: [2, 2, 7])

        let engine = WhatsForDinnerEngine()
        let standings = session.standings(using: engine)
        XCTAssertEqual(standings.first { $0.player.name == "Alice" }?.rank, 1)
        XCTAssertEqual(standings.first { $0.player.name == "Bob" }?.rank, 1)
        XCTAssertEqual(standings.first { $0.player.name == "Cara" }?.rank, 3)
    }

    @MainActor
    func testStatsTreatMixedCaseLegacyNamesAsOnePlayer() {
        let legacy = makeSession(gameType: .generic, names: ["Alice", "Bob"])
        appendRound(to: legacy, scores: [10, 5])
        let current = makeSession(gameType: .generic, names: ["alice", "bob"])
        appendRound(to: current, scores: [2, 5])

        let stats = StatsCalculator.stats(for: "alice", sessions: [legacy, current])
        XCTAssertEqual(stats.gamesPlayed, 2)
        XCTAssertEqual(stats.wins, 1)

        let headToHead = StatsCalculator.headToHead("Alice", vs: "bob", sessions: [legacy, current])
        XCTAssertEqual(headToHead.gamesTogether, 2)
        XCTAssertEqual(headToHead.aWins, 1)
        XCTAssertEqual(
            StatsCalculator.gamesBetween("alice", and: "Bob", gameType: .generic, sessions: [legacy, current]).count,
            2
        )
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

    @MainActor
    func testGenericSubmissionPersistsRoundCompletionAndWinnersTogetherOnDisk() throws {
        for condition in [WinCondition.highestScore, .lowestScore] {
            for points in [[10, 4], [12, 12]] {
                try withDiskStore { container, url in
                    let context = ModelContext(container)
                    context.autosaveEnabled = true
                    let session = makeSession(targetScore: 10, winCondition: condition)
                    context.insert(session)
                    try context.save()
                    let names = session.players.map(\.name)
                    let scores = Dictionary(uniqueKeysWithValues: zip(session.players.map(\.id), points))
                    try GenericRoundPersistence.submit(session: session, scores: scores, context: context)
                    XCTAssertTrue(context.autosaveEnabled)
                    let reopened = try reopenSession(at: url)
                    XCTAssertTrue(reopened.isComplete)
                    XCTAssertEqual(reopened.rounds.count, 1)
                    XCTAssertEqual(reopened.rounds[0].entries.count, 2)
                    XCTAssertEqual(reopened.completedAt, reopened.rounds[0].createdAt)
                    let winnerNames = Set(GenericEngine().winners(session: reopened).compactMap { id in
                        reopened.players.first { $0.id == id }?.name
                    })
                    let expected: Set<String> = points[0] == points[1] ? Set(names) : [condition == .highestScore ? names[0] : names[1]]
                    XCTAssertEqual(winnerNames, expected)
                    XCTAssertTrue(GenericEngine().winners(session: reopened).contains(reopened.winnerID!))
                }
            }
        }
    }

    @MainActor
    func testFailedGenericSaveRestoresOnlyRoundDraftAndRetryDoesNotDuplicate() throws {
        try withDiskStore { container, url in
            let context = ModelContext(container)
            context.autosaveEnabled = true
            let session = makeSession(targetScore: 10, winCondition: .highestScore)
            let unrelated = makeSession(targetScore: nil, winCondition: .highestScore)
            context.insert(session)
            context.insert(unrelated)
            try context.save()
            unrelated.targetScore = 77
            let scores = Dictionary(uniqueKeysWithValues: zip(session.players.map(\.id), [10, 4]))
            XCTAssertThrowsError(try GenericRoundPersistence.submit(session: session, scores: scores, context: context) { _ in
                throw NSError(domain: "InjectedSaveFailure", code: 1)
            })
            XCTAssertTrue(context.autosaveEnabled)
            XCTAssertFalse(session.isComplete)
            XCTAssertNil(session.completedAt)
            XCTAssertNil(session.winnerID)
            XCTAssertEqual(session.rounds.count, 0)
            XCTAssertEqual(unrelated.targetScore, 77)
            let disk = try diskContainer(at: url)
            let reader = ModelContext(disk)
            XCTAssertEqual(try reader.fetch(FetchDescriptor<Round>()).count, 0)
            XCTAssertEqual(try reader.fetch(FetchDescriptor<ScoreEntry>()).count, 0)
            XCTAssertTrue(try reader.fetch(FetchDescriptor<GameSession>()).allSatisfy { !$0.isComplete })
            try context.save()
            XCTAssertEqual(try reader.fetch(FetchDescriptor<Round>()).count, 0)
            try GenericRoundPersistence.submit(session: session, scores: scores, context: context)
            let reopened = ModelContext(try diskContainer(at: url))
            XCTAssertEqual(try reopened.fetch(FetchDescriptor<Round>()).count, 1)
            XCTAssertEqual(try reopened.fetch(FetchDescriptor<ScoreEntry>()).count, 2)
            XCTAssertEqual(try reopened.fetch(FetchDescriptor<GameSession>()).filter(\.isComplete).count, 1)
            XCTAssertThrowsError(try GenericRoundPersistence.submit(session: session, scores: scores, context: context))
        }
    }

    @MainActor
    func testGenericResumeReconcilesStrandedSessionWithoutNewScoresAndKeepsOriginalDate() throws {
        try withDiskStore { container, url in
            let context = ModelContext(container)
            let session = makeSession(targetScore: 10, winCondition: .highestScore)
            appendRound(to: session, scores: [10, 4])
            let originalDate = Date(timeIntervalSince1970: 1_600_000_000)
            session.rounds[0].createdAt = originalDate
            context.insert(session)
            try context.save()
            let resumeContainer = try diskContainer(at: url)
            let resumeContext = ModelContext(resumeContainer)
            let stranded = try XCTUnwrap(resumeContext.fetch(FetchDescriptor<GameSession>()).first)
            XCTAssertFalse(stranded.isComplete)
            XCTAssertThrowsError(try GenericRoundPersistence.reconcile(session: stranded, context: resumeContext) { _ in
                throw NSError(domain: "InjectedSaveFailure", code: 1)
            })
            XCTAssertFalse(stranded.isComplete)
            XCTAssertNil(stranded.completedAt)
            try GenericRoundPersistence.reconcile(session: stranded, context: resumeContext)
            try GenericRoundPersistence.reconcile(session: stranded, context: resumeContext) { _ in
                XCTFail("A reconciled session must not save again")
            }
            let reopened = try reopenSession(at: url)
            XCTAssertTrue(reopened.isComplete)
            XCTAssertEqual(reopened.completedAt, originalDate)
            XCTAssertEqual(reopened.rounds.count, 1)
            XCTAssertEqual(reopened.rounds[0].entries.map(\.points).sorted(), [4, 10])
            XCTAssertEqual(reopened.players.first { $0.id == reopened.winnerID }?.name, "Alice")
        }
    }

    @MainActor
    func testGenericPersistenceKeepsZeroInvalidNoTargetAndNonqualifyingGamesManual() throws {
        for target in [nil, 0, -1, 10] as [Int?] {
            for condition in [WinCondition.highestScore, .lowestScore] {
                try withDiskStore { container, url in
                    let context = ModelContext(container)
                    let session = makeSession(targetScore: target, winCondition: condition)
                    context.insert(session)
                    try context.save()
                    try GenericRoundPersistence.reconcile(session: session, context: context) { _ in
                        XCTFail("A game without rounds must not save on resume")
                    }
                    let points = target == 10 ? [4, 0] : [100, 0]
                    let scores = Dictionary(uniqueKeysWithValues: zip(session.players.map(\.id), points))
                    try GenericRoundPersistence.submit(session: session, scores: scores, context: context)
                    try GenericRoundPersistence.reconcile(session: session, context: context) { _ in
                        XCTFail("A manual-only or nonqualifying game must not save on resume")
                    }
                    let reopened = try reopenSession(at: url)
                    XCTAssertFalse(reopened.isComplete)
                    XCTAssertNil(reopened.completedAt)
                    XCTAssertNil(reopened.winnerID)
                    XCTAssertEqual(reopened.rounds.count, 1)
                }
            }
        }
        for gameType in [GameType.phase10, .whatsForDinner] {
            try withDiskStore { container, url in
                let context = ModelContext(container)
                let session = makeSession(gameType: gameType, names: ["Alice", "Bob"], targetScore: 10)
                appendRound(to: session, scores: [100, 0])
                context.insert(session)
                try context.save()
                try GenericRoundPersistence.reconcile(session: session, context: context) { _ in
                    XCTFail("Generic resume must not change another game's completion")
                }
                XCTAssertFalse(try reopenSession(at: url).isComplete)
                XCTAssertEqual(session.rounds.count, 1)
            }
        }
        try withDiskStore { container, url in
            let context = ModelContext(container)
            let session = makeSession(targetScore: 10, winCondition: .highestScore)
            context.insert(session)
            try context.save()
            try GenericRoundPersistence.submit(session: session, scores: Dictionary(uniqueKeysWithValues: session.players.map { ($0.id, 0) }), context: context)
            XCTAssertFalse(try reopenSession(at: url).isComplete)
            XCTAssertEqual(session.rounds.count, 1)
            XCTAssertThrowsError(try GenericRoundPersistence.submit(session: session, scores: [:], context: context))
            XCTAssertEqual(session.rounds.count, 1)
        }
    }

    @MainActor
    func testMixedCaseChoicesOpponentsAndSelfMatchUseTheSameIdentityWithoutChangingTotals() {
        let legacy = makeSession(gameType: .generic, names: ["Alice", "Bob", "Alicia"])
        appendRound(to: legacy, scores: [10, 5, 1])
        let current = makeSession(gameType: .generic, names: ["alice", "bob"])
        appendRound(to: current, scores: [2, 5])
        let sessions = [legacy, current]
        XCTAssertEqual(StatsCalculator.allPlayerNames(from: sessions), ["Alice", "Alicia", "Bob"])
        XCTAssertEqual(StatsCalculator.allPlayerNames(from: Array(sessions.reversed())), ["Alice", "Alicia", "Bob"])
        XCTAssertEqual(StatsCalculator.opponentNames(for: "alice", sessions: sessions), ["Alicia", "Bob"])
        XCTAssertEqual(StatsCalculator.opponentNames(for: "BOB", sessions: sessions), ["Alice", "Alicia"])
        XCTAssertEqual(StatsCalculator.headToHead("Alice", vs: "alice", sessions: sessions).gamesTogether, 0)
        XCTAssertEqual(StatsCalculator.headToHeadByGameType("Alice", vs: "alice", sessions: sessions).count, 0)
        XCTAssertEqual(StatsCalculator.gamesBetween("Alice", and: "alice", gameType: .generic, sessions: sessions).count, 0)
        let stats = StatsCalculator.stats(for: "alice", sessions: sessions)
        XCTAssertEqual(stats.gamesPlayed, 2)
        XCTAssertEqual(stats.wins, 1)
        XCTAssertEqual(stats.avgScore, 6)
        XCTAssertEqual(StatsCalculator.headToHead("Alice", vs: "Bob", sessions: sessions).gamesTogether, 2)
        XCTAssertEqual(legacy.players.map(\.name), ["Alice", "Bob", "Alicia"])
        XCTAssertEqual(current.players.map(\.name), ["alice", "bob"])
    }

    @MainActor
    func testSwiftDataSaveErrorDoesNotLeaveAnAutosavableQualifyingRound() throws {
        try withDiskStore { container, url in
            let originalContext = ModelContext(container)
            let session = makeSession(targetScore: 10, winCondition: .highestScore)
            originalContext.insert(session)
            try originalContext.save()
            let schema = Schema([GameSession.self, Player.self, Round.self, ScoreEntry.self])
            let readOnly = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url, allowsSave: false, cloudKitDatabase: .none))
            let context = ModelContext(readOnly)
            context.autosaveEnabled = true
            let readOnlySession = try XCTUnwrap(context.fetch(FetchDescriptor<GameSession>()).first)
            let scores = Dictionary(uniqueKeysWithValues: zip(readOnlySession.players.map(\.id), [10, 4]))
            XCTAssertThrowsError(try GenericRoundPersistence.submit(session: readOnlySession, scores: scores, context: context))
            XCTAssertTrue(context.autosaveEnabled)
            XCTAssertFalse(readOnlySession.isComplete)
            XCTAssertEqual(readOnlySession.rounds.count, 0)
            let reopened = try reopenSession(at: url)
            XCTAssertFalse(reopened.isComplete)
            XCTAssertNil(reopened.completedAt)
            XCTAssertEqual(reopened.rounds.count, 0)
        }
    }

    @MainActor
    func testScoringScreenResumeReconcilesDiskSessionAndRoutesOnce() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("scoring-view-regression-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("scores.store")
        let container = try diskContainer(at: url)
        let context = container.mainContext
        let session = makeSession(targetScore: 10, winCondition: .highestScore)
        appendRound(to: session, scores: [10, 4])
        let originalDate = Date(timeIntervalSince1970: 1_600_000_000)
        session.rounds[0].createdAt = originalDate
        context.insert(session)
        try context.save()
        let router = NavigationRouter()
        router.configure(reduceMotion: true)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        let host = UIHostingController(rootView: NavigationStack {
            ScoringView(sessionID: session.persistentModelID)
        }.environment(router).modelContainer(container))
        window.rootViewController = host
        window.isHidden = false
        defer { window.isHidden = true; window.rootViewController = nil }
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(5))
        while router.path.isEmpty && clock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertEqual(router.path, NavigationPath([AppDestination.gameOver(session.persistentModelID)]))
        XCTAssertTrue(session.isComplete)
        XCTAssertEqual(session.completedAt, originalDate)
        XCTAssertEqual(session.rounds.count, 1)
        let reopened = try reopenSession(at: url)
        XCTAssertTrue(reopened.isComplete)
        XCTAssertEqual(reopened.completedAt, originalDate)
        XCTAssertEqual(reopened.rounds.count, 1)
    }

    @MainActor
    private func diskContainer(at url: URL) throws -> ModelContainer {
        let schema = Schema([GameSession.self, Player.self, Round.self, ScoreEntry.self])
        return try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none))
    }

    @MainActor
    private func reopenSession(at url: URL) throws -> GameSession {
        let context = ModelContext(try diskContainer(at: url))
        return try XCTUnwrap(context.fetch(FetchDescriptor<GameSession>()).first)
    }

    @MainActor
    private func withDiskStore(_ body: (ModelContainer, URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("scoring-regression-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("scores.store")
        try body(diskContainer(at: url), url)
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
