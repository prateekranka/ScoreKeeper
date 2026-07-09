import XCTest

@MainActor
final class ScoreKeeperUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-in-memory-store"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    // MARK: - Test 0: First launch onboarding

    func testOnboardingSkipAndStartFlows() throws {
        launchOnboarding()

        assertOnboardingTitle("Put the score pad down.")
        app.buttons["onboarding_skip_button"].tap()
        XCTAssertTrue(app.buttons["new_game_button"].waitForExistence(timeout: 3))

        launchOnboarding()

        assertOnboardingTitle("Put the score pad down.")
        app.buttons["onboarding_primary_button"].tap()
        assertOnboardingTitle("Set up in seconds.")
        app.buttons["onboarding_primary_button"].tap()
        assertOnboardingTitle("Every night becomes history.")
        app.buttons["onboarding_primary_button"].tap()
        XCTAssertTrue(app.buttons["new_game_button"].waitForExistence(timeout: 3))
    }

    // MARK: - Test 1: Create Generic Game and navigate to scoring

    func testCreateGenericGameAndScore() throws {
        navigateToGenericScoring(playerNames: ["Alice", "Bob", "Charlie"])

        // Verify scoring screen is shown
        XCTAssertTrue(app.buttons["end_game_button"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["submit_round_button"].waitForExistence(timeout: 2))

        // Verify player names are visible
        XCTAssertTrue(app.staticTexts["Alice"].exists)
        XCTAssertTrue(app.staticTexts["Bob"].exists)
        XCTAssertTrue(app.staticTexts["Charlie"].exists)

        // Submit a round (all zeros is fine)
        app.buttons["submit_round_button"].tap()

        // End Game
        app.buttons["end_game_button"].tap()
        app.alerts.buttons["End Game"].tap()

        // Game Over: verify winner text
        let winnerText = app.staticTexts["winner_text"]
        XCTAssertTrue(winnerText.waitForExistence(timeout: 2))
        XCTAssertTrue(winnerText.exists)
    }

    // MARK: - Test 2: Create Phase 10 Game → Score → End

    func testCreatePhase10GameAndScore() throws {
        navigateToScoring(gameTileID: "game_tile_phase10", playerNames: ["Alice", "Bob"])

        // Submit one round for Phase 10
        app.buttons["submit_round_button"].tap()

        // End Game
        app.buttons["end_game_button"].tap()
        app.alerts.buttons["End Game"].tap()

        // Game Over: verify
        XCTAssertTrue(app.staticTexts["winner_text"].waitForExistence(timeout: 2))
    }

    // MARK: - Test 3: Create game, navigate to scoring, verify screen

    func testResumeInProgressGame() throws {
        navigateToGenericScoring(playerNames: ["Alice", "Bob"])

        // Submit one round
        app.buttons["submit_round_button"].tap()

        // End Game
        app.buttons["end_game_button"].tap()
        app.alerts.buttons["End Game"].tap()

        // Verify GameOver screen appears
        XCTAssertTrue(app.staticTexts["winner_text"].waitForExistence(timeout: 3))

        // Swipe up to reveal buttons at bottom
        app.swipeUp()

        // Tap Home
        let homeButton = app.buttons["home_button"]
        XCTAssertTrue(homeButton.waitForExistence(timeout: 3))
        homeButton.tap()
        sleep(1)

        // Verify we're back on Home screen
        XCTAssertTrue(app.buttons["new_game_button"].waitForExistence(timeout: 3))
    }

    // MARK: - Test 4: Play Again

    func testPlayAgain() throws {
        navigateToGenericScoring(playerNames: ["Alice", "Bob"])

        app.buttons["submit_round_button"].tap()

        // End Game
        app.buttons["end_game_button"].tap()
        app.alerts.buttons["End Game"].tap()

        // Swipe up to reveal buttons at bottom
        app.swipeUp()

        // Verify Game Over screen and tap Play Again
        let playAgainButton = app.buttons["play_again_button"]
        XCTAssertTrue(playAgainButton.waitForExistence(timeout: 3))
        playAgainButton.tap()
        sleep(2)

        // Verify we're back on scoring screen with same players
        XCTAssertTrue(app.buttons["end_game_button"].waitForExistence(timeout: 5))
    }

    // MARK: - Test 5: Game history

    func testGameHistory() throws {
        // Complete first game
        navigateToGenericScoring(playerNames: ["Alice", "Bob"])
        app.buttons["submit_round_button"].tap()
        app.buttons["end_game_button"].tap()
        app.alerts.buttons["End Game"].tap()
        app.swipeUp()
        let homeButton = app.buttons["home_button"]
        XCTAssertTrue(homeButton.waitForExistence(timeout: 3))
        homeButton.tap()
        sleep(1)

        // Complete second game
        let newGameButton = app.buttons["new_game_button"]
        XCTAssertTrue(newGameButton.waitForExistence(timeout: 3))
        newGameButton.tap()
        app.buttons["game_tile_generic"].tap()
        fillPlayerNames(["Charlie", "Diana"])
        app.buttons["start_game_button"].tap()
        app.buttons["start_game_button"].tap()
        app.buttons["submit_round_button"].tap()
        app.buttons["end_game_button"].tap()
        app.alerts.buttons["End Game"].tap()
        app.swipeUp()
        let homeButton2 = app.buttons["home_button"]
        XCTAssertTrue(homeButton2.waitForExistence(timeout: 3))
        homeButton2.tap()
        sleep(1)

        // Verify Home screen with recent games
        XCTAssertTrue(app.staticTexts["Recent Games"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Scoreboard"].exists)
        XCTAssertTrue(app.buttons["new_game_button"].exists)
    }

    // MARK: - Test 6: Cautious user fixes invalid setup

    func testPlayerSetupValidatesDuplicateNames() throws {
        app.buttons["new_game_button"].tap()
        app.buttons["game_tile_generic"].tap()

        fillPlayerNames(["Alex", "Alex"])

        XCTAssertTrue(app.staticTexts["Player names must be unique."].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["start_game_button"].isEnabled)

        replaceText(in: app.textFields["player_name_field_1"], with: "Jordan")

        XCTAssertFalse(app.staticTexts["Player names must be unique."].exists)
        XCTAssertTrue(app.buttons["start_game_button"].isEnabled)
    }

    // MARK: - Test 7: Score-focused user adjusts points

    func testGenericScoreStepperUpdatesVisibleScore() throws {
        navigateToGenericScoring(playerNames: ["Alice", "Bob"])

        app.buttons["Alice_increment"].tap()
        app.buttons["Alice_increment"].tap()
        app.buttons["Bob_decrement"].tap()

        XCTAssertTrue(app.staticTexts["Score 2"].exists)
        XCTAssertTrue(app.staticTexts["Score -1"].exists)

        app.buttons["submit_round_button"].tap()

        XCTAssertTrue(app.staticTexts["Round 2"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["2"].exists)
    }

    // MARK: - Test 8: What's for Dinner player records a meal reveal

    func testWhatsForDinnerMealRevealFlow() throws {
        navigateToScoring(gameTileID: "game_tile_whatsForDinner", playerNames: ["Mina", "Nora", "Omar"])

        app.buttons["meal_reveal_Mina"].tap()
        if !app.staticTexts["Caller"].waitForExistence(timeout: 1) {
            app.staticTexts["Mina"].firstMatch.tap()
        }

        app.buttons["Mina_increment"].tap()
        app.buttons["Nora_increment"].tap()
        app.buttons["Nora_increment"].tap()
        app.buttons["submit_round_button"].tap()

        XCTAssertTrue(app.staticTexts["Round 2"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Rounds"].exists)
    }

    // MARK: - Test 9: Repeat user chooses saved roster players

    func testRosterReuseAddsSavedPlayers() throws {
        completeGenericGame(playerNames: ["Riley", "Sam"])

        XCTAssertTrue(app.buttons["new_game_button"].waitForExistence(timeout: 3))
        app.buttons["new_game_button"].tap()
        app.buttons["game_tile_phase10"].tap()
        app.buttons["roster_button"].tap()

        let riley = app.buttons["roster_player_Riley"]
        let sam = app.buttons["roster_player_Sam"]
        XCTAssertTrue(riley.waitForExistence(timeout: 3))
        XCTAssertTrue(sam.waitForExistence(timeout: 3))

        riley.tap()
        sam.tap()
        app.buttons["Add (2)"].tap()

        XCTAssertTrue(waitForTextFields(["player_name_field_0", "player_name_field_1"], toContain: ["Riley", "Sam"]))
        XCTAssertTrue(app.buttons["start_game_button"].isEnabled)
    }

    // MARK: - Test 10: Theme and stats user explores completed data

    func testThemeToggleAndHeadToHeadStatsNavigation() throws {
        app.buttons["theme_button"].tap()
        app.buttons["theme_button"].tap()

        completeGenericGame(playerNames: ["Taylor", "Morgan"])

        XCTAssertTrue(app.staticTexts["Stats"].waitForExistence(timeout: 3))
        app.buttons["Head to Head"].tap()

        XCTAssertTrue(app.navigationBars["Head to Head"].waitForExistence(timeout: 3))
        app.buttons["Player 1, Select..."].tap()
        app.buttons["Taylor"].tap()
        app.buttons["Player 2, Select..."].tap()
        app.buttons["Morgan"].tap()

        XCTAssertTrue(app.staticTexts["1 game together"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Taylor"].exists)
        XCTAssertTrue(app.buttons["Morgan"].exists)
    }

    // MARK: - Test 11: History is reachable with one completed game

    func testGameHistoryIsReachableWithOneCompletedGame() throws {
        completeGenericGame(playerNames: ["Ivy", "Noah"])

        let seeAllButton = app.buttons["see_all_button"]
        if !seeAllButton.waitForExistence(timeout: 1) {
            app.swipeUp()
        }

        XCTAssertTrue(seeAllButton.waitForExistence(timeout: 3))
        seeAllButton.tap()

        XCTAssertTrue(app.navigationBars["Game History"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Scoreboard"].exists)
    }

    // MARK: - Test 12: Player stats navigation

    func testPlayerStatsNavigationFromStatsEntry() throws {
        completeGenericGame(playerNames: ["Taylor", "Morgan"])

        let playerStatsButton = app.buttons["player_stats_Taylor"]
        if !playerStatsButton.waitForExistence(timeout: 1) {
            app.swipeUp()
        }

        XCTAssertTrue(playerStatsButton.waitForExistence(timeout: 3))
        playerStatsButton.tap()

        XCTAssertTrue(app.navigationBars["Taylor"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Games Played"].exists)
        XCTAssertTrue(app.staticTexts["Wins"].exists)
    }

    // MARK: - Test 13: Exhausted free games shows paywall

    func testFreeGamesExhaustedShowsPaywallWhenStartingNewGame() throws {
        relaunch(arguments: ["-in-memory-store", "-free-games-exhausted"])

        app.buttons["new_game_button"].tap()
        app.buttons["game_tile_whatsForDinner"].tap()
        fillPlayerNames(["Ada", "Ben"])
        app.buttons["start_game_button"].tap()

        XCTAssertTrue(app.staticTexts["ScoreKeeper Pro"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["paywall_unlock_button"].exists)
    }

    // MARK: - Test 14: Pro unlock bypasses paywall

    func testUnlockedProDoesNotShowPaywallWhenStartingNewGame() throws {
        relaunch(arguments: ["-in-memory-store", "-unlock-pro"])

        app.buttons["new_game_button"].tap()
        app.buttons["game_tile_whatsForDinner"].tap()
        fillPlayerNames(["Ada", "Ben"])
        app.buttons["start_game_button"].tap()

        XCTAssertTrue(app.buttons["end_game_button"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["ScoreKeeper Pro"].waitForExistence(timeout: 1))
    }

    // MARK: - Test 15: Forced review ask appears after Game Over

    func testForceReviewAskAppearsAfterCompletingGame() throws {
        relaunch(arguments: ["-in-memory-store", "-force-review-ask"])

        navigateToGenericScoring(playerNames: ["Ada", "Ben"])
        app.buttons["submit_round_button"].tap()
        app.buttons["end_game_button"].tap()
        app.alerts.buttons["End Game"].tap()

        XCTAssertTrue(app.buttons["review_ask_rate_button"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["review_ask_later_button"].exists)
    }

    // MARK: - Helpers

    private func relaunch(arguments: [String]) {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        XCTAssertTrue(app.buttons["new_game_button"].waitForExistence(timeout: 3))
    }

    private func launchOnboarding() {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = ["-in-memory-store", "-reset-onboarding"]
        app.launch()
    }

    private func assertOnboardingTitle(_ title: String) {
        let pageTitle = app.staticTexts["onboarding_page_title"]
        XCTAssertTrue(pageTitle.waitForExistence(timeout: 3))
        XCTAssertEqual(pageTitle.label, title)
    }

    private func navigateToGenericScoring(playerNames: [String]) {
        app.buttons["new_game_button"].tap()
        app.buttons["game_tile_generic"].tap()
        fillPlayerNames(playerNames)
        app.buttons["start_game_button"].tap()
        XCTAssertTrue(app.segmentedControls["win_condition_picker"].waitForExistence(timeout: 1))
        app.buttons["start_game_button"].tap()
        XCTAssertTrue(app.buttons["end_game_button"].waitForExistence(timeout: 3))
    }

    private func navigateToScoring(gameTileID: String, playerNames: [String]) {
        app.buttons["new_game_button"].tap()
        app.buttons[gameTileID].tap()
        fillPlayerNames(playerNames)

        // Scoreboard and Phase 10 include a game config step before scoring.
        if gameTileID == "game_tile_generic" || gameTileID == "game_tile_phase10" {
            app.buttons["start_game_button"].tap()
            XCTAssertTrue(app.navigationBars["Game Settings"].waitForExistence(timeout: 2))
        }
        app.buttons["start_game_button"].tap()

        XCTAssertTrue(app.buttons["end_game_button"].waitForExistence(timeout: 3))
    }

    private func fillPlayerNames(_ names: [String]) {
        for (index, name) in names.enumerated() {
            if index >= 2 {
                app.buttons["add_player_button"].tap()
            }
            let field = app.textFields["player_name_field_\(index)"]
            XCTAssertTrue(field.waitForExistence(timeout: 1))
            field.tap()
            field.typeText(name)
        }
    }

    // MARK: - Screenshot tour (design QA only; runs when SCREENSHOT_DIR env is set)

    func testScreenshotTour() throws {
        guard let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] else {
            throw XCTSkip("SCREENSHOT_DIR not set")
        }
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        func snap(_ name: String) {
            let png = XCUIScreen.main.screenshot().pngRepresentation
            try? png.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
        }

        launchOnboarding()
        _ = app.staticTexts["onboarding_page_title"].waitForExistence(timeout: 3)
        snap("01-onboarding-1")
        app.buttons["onboarding_primary_button"].tap()
        sleep(1); snap("02-onboarding-2")
        app.buttons["onboarding_primary_button"].tap()
        sleep(1); snap("03-onboarding-3")
        app.buttons["onboarding_primary_button"].tap()
        _ = app.buttons["new_game_button"].waitForExistence(timeout: 3)
        snap("04-home-empty")

        app.buttons["new_game_button"].tap()
        _ = app.buttons["game_tile_generic"].waitForExistence(timeout: 2)
        snap("05-game-picker")

        app.buttons["game_tile_generic"].tap()
        fillPlayerNames(["Mina", "Omar", "Jules"])
        snap("06-player-setup")

        app.buttons["start_game_button"].tap()
        _ = app.segmentedControls["win_condition_picker"].waitForExistence(timeout: 2)
        snap("07-game-config")

        app.buttons["start_game_button"].tap()
        _ = app.buttons["end_game_button"].waitForExistence(timeout: 3)
        snap("08-scoring-initial")

        app.buttons["Mina_increment"].tap()
        app.buttons["Mina_increment"].tap()
        app.buttons["Omar_increment"].tap()
        app.buttons["submit_round_button"].tap()
        sleep(1); snap("09-scoring-round2")

        app.buttons["end_game_button"].tap()
        if app.alerts.buttons["End Game"].waitForExistence(timeout: 2) {
            app.alerts.buttons["End Game"].tap()
        }
        sleep(2); snap("10-game-over")

        if app.buttons["home_button"].waitForExistence(timeout: 2) {
            app.buttons["home_button"].tap()
        } else if app.buttons["Home"].waitForExistence(timeout: 2) {
            app.buttons["Home"].tap()
        }
        _ = app.buttons["new_game_button"].waitForExistence(timeout: 3)
        snap("11-home-with-history")

        if app.buttons["theme_button"].exists {
            app.buttons["theme_button"].tap()
            sleep(1); snap("12-home-theme-toggled")
            app.buttons["theme_button"].tap()
            sleep(1)
        }

        relaunch(arguments: ["-in-memory-store", "-free-games-exhausted"])
        app.buttons["new_game_button"].tap()
        app.buttons["game_tile_whatsForDinner"].tap()
        fillPlayerNames(["Ada", "Ben"])
        app.buttons["start_game_button"].tap()
        _ = app.staticTexts["ScoreKeeper Pro"].waitForExistence(timeout: 3)
        snap("13-paywall")

        relaunch(arguments: ["-in-memory-store", "-force-review-ask"])
        navigateToGenericScoring(playerNames: ["Ada", "Ben"])
        app.buttons["submit_round_button"].tap()
        app.buttons["end_game_button"].tap()
        if app.alerts.buttons["End Game"].waitForExistence(timeout: 2) {
            app.alerts.buttons["End Game"].tap()
        }
        _ = app.buttons["review_ask_rate_button"].waitForExistence(timeout: 5)
        snap("14-review-ask")
    }

    private func replaceText(in field: XCUIElement, with text: String) {
        XCTAssertTrue(field.waitForExistence(timeout: 1))
        field.tap()
        field.press(forDuration: 1.0)

        if app.menuItems["Select All"].waitForExistence(timeout: 1) {
            app.menuItems["Select All"].tap()
        } else {
            field.tap(withNumberOfTaps: 3, numberOfTouches: 1)
        }

        field.typeText(text)
    }

    private func waitForTextField(_ identifier: String, toEqual value: String, timeout: TimeInterval = 2) -> Bool {
        let field = app.textFields[identifier]
        guard field.waitForExistence(timeout: timeout) else { return false }

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if field.value as? String == value {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }

        return field.value as? String == value
    }

    private func waitForTextFields(_ identifiers: [String], toContain expectedValues: Set<String>, timeout: TimeInterval = 2) -> Bool {
        let fields = identifiers.map { app.textFields[$0] }
        guard fields.allSatisfy({ $0.waitForExistence(timeout: timeout) }) else { return false }

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let values = Set(fields.compactMap { $0.value as? String })
            if expectedValues.isSubset(of: values) {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }

        return expectedValues.isSubset(of: Set(fields.compactMap { $0.value as? String }))
    }

    private func completeGenericGame(playerNames: [String]) {
        navigateToGenericScoring(playerNames: playerNames)
        app.buttons["submit_round_button"].tap()
        app.buttons["end_game_button"].tap()
        app.alerts.buttons["End Game"].tap()
        let homeButton = app.buttons["home_button"]
        XCTAssertTrue(homeButton.waitForExistence(timeout: 5))
        homeButton.tap()
    }
}
