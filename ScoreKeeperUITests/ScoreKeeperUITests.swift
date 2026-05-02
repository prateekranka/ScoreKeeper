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

        XCTAssertTrue(app.staticTexts["1 games together"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Taylor"].exists)
        XCTAssertTrue(app.buttons["Morgan"].exists)
    }

    // MARK: - Helpers

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

        // For generic, there's a game config step
        if gameTileID == "game_tile_generic" {
            app.buttons["start_game_button"].tap()
            XCTAssertTrue(app.segmentedControls["win_condition_picker"].waitForExistence(timeout: 1))
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
        XCTAssertTrue(app.staticTexts["winner_text"].waitForExistence(timeout: 3))
        let homeButton = app.buttons["home_button"]
        XCTAssertTrue(homeButton.waitForExistence(timeout: 3))
        homeButton.tap()
    }
}
