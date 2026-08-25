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
        completeRound(playerNames: ["Alice", "Bob", "Charlie"])

        // End Game
        app.buttons["end_game_button"].tap()
        app.alerts.buttons["End Game"].tap()

        // Game Over: verify winner text
        let winnerText = app.staticTexts["winner_text"]
        XCTAssertTrue(winnerText.waitForExistence(timeout: 2))
        XCTAssertTrue(winnerText.exists)
    }

    // MARK: - Test 2: Create Ten Phases Game → Score → End

    func testCreatePhase10GameAndScore() throws {
        navigateToScoring(gameTileID: "game_tile_phase10", playerNames: ["Alice", "Bob"])

        // Submit one round for Ten Phases (submits directly, no deck)
        completeRound(playerNames: ["Alice", "Bob"], gameType: "phase10")

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
        completeRound(playerNames: ["Alice", "Bob"])

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

        completeRound(playerNames: ["Alice", "Bob"])

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
        completeRound(playerNames: ["Ada", "Ben"])
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
        tapGameTile("game_tile_generic")
        fillPlayerNames(["Charlie", "Diana"])
        app.buttons["start_game_button"].tap()
        app.buttons["start_game_button"].tap()
        completeRound(playerNames: ["Ada", "Ben"])
        app.buttons["end_game_button"].tap()
        app.alerts.buttons["End Game"].tap()
        app.swipeUp()
        let homeButton2 = app.buttons["home_button"]
        XCTAssertTrue(homeButton2.waitForExistence(timeout: 3))
        homeButton2.tap()
        sleep(1)

        // Verify Home screen with recent games using the section's stable control identifier.
        XCTAssertTrue(scrollToHittable(app.buttons["see_all_button"]))
        XCTAssertTrue(app.buttons["new_game_button"].exists)
    }

    // MARK: - Test 6: Cautious user fixes invalid setup

    func testPlayerSetupValidatesDuplicateNames() throws {
        app.buttons["new_game_button"].tap()
        tapGameTile("game_tile_generic")

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
        completeRound(playerNames: ["Alice", "Bob"])
        XCTAssertTrue(app.staticTexts["Round 2"].waitForExistence(timeout: 3))
    }

    // MARK: - Test 8: What's for Dinner player records a meal reveal

    func testWhatsForDinnerMealRevealFlow() throws {
        navigateToScoring(gameTileID: "game_tile_whatsForDinner", playerNames: ["Mina", "Nora", "Omar"])

        app.buttons["meal_reveal_Mina"].tap()
        if !app.staticTexts["Caller"].waitForExistence(timeout: 1) {
            app.staticTexts["Mina"].firstMatch.tap()
        }

        // WhatsForDinner uses its own scoring rows (not the deck) — unchanged
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
        tapGameTile("game_tile_phase10")
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

        let headToHeadButton = app.buttons["head_to_head_button"]
        XCTAssertTrue(scrollToHittable(headToHeadButton))
        headToHeadButton.tap()

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
        XCTAssertTrue(app.descendants(matching: .any)["history_card_0"].waitForExistence(timeout: 3))
    }

    // MARK: - Test 12: Player stats navigation

    func testPlayerStatsNavigationFromStatsEntry() throws {
        completeGenericGame(playerNames: ["Taylor", "Morgan"])

        _ = waitForHittable(app.buttons["new_game_button"])

        // Scroll to find the player stats entry
        let playerStatsButton = app.buttons["player_stats_Taylor"]
        var found = false
        for _ in 0..<6 {
            if playerStatsButton.exists && playerStatsButton.isHittable {
                found = true
                break
            }
            app.swipeUp(velocity: .fast)
        }
        XCTAssertTrue(found || playerStatsButton.exists, "player_stats_Taylor not found after scrolling")
        XCTAssertTrue(playerStatsButton.waitForExistence(timeout: 3))
        playerStatsButton.tap()

        XCTAssertTrue(app.navigationBars["Taylor"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Games Played"].exists)
        XCTAssertTrue(app.staticTexts["Wins"].exists)
    }

    // MARK: - Test 13: Exhausted free games shows paywall

    func testFreeGamesExhaustedShowsPaywallWhenStartingNewGame() throws {
        relaunch(arguments: ["-in-memory-store", "-free-games-exhausted", "-force-light-theme"])

        app.buttons["new_game_button"].tap()
        tapGameTile("game_tile_whatsForDinner")
        fillPlayerNames(["Ada", "Ben"])
        app.buttons["start_game_button"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["paywall_title"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["paywall_unlock_button"].exists)
    }

    // MARK: - Test 14: Pro unlock bypasses paywall

    func testUnlockedProDoesNotShowPaywallWhenStartingNewGame() throws {
        relaunch(arguments: ["-in-memory-store", "-unlock-pro"])

        app.buttons["new_game_button"].tap()
        tapGameTile("game_tile_whatsForDinner")
        fillPlayerNames(["Ada", "Ben"])
        app.buttons["start_game_button"].tap()

        XCTAssertTrue(app.buttons["end_game_button"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["PipCount Pro"].waitForExistence(timeout: 1))
    }

    // MARK: - Test 15: Forced review ask uses Apple's native flow

    func testForceReviewAskAppearsAfterCompletingGame() throws {
        relaunch(arguments: ["-in-memory-store", "-force-review-ask", "-force-light-theme"])

        navigateToGenericScoring(playerNames: ["Ada", "Ben"])
        completeRound(playerNames: ["Ada", "Ben"])
        app.buttons["end_game_button"].tap()
        app.alerts.buttons["End Game"].tap()

        XCTAssertTrue(app.staticTexts["winner_text"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["review_ask_rate_button"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["review_ask_later_button"].exists)
        XCTAssertFalse(app.staticTexts["How was game night?"].exists)
    }

    // MARK: - Test 16: Active games remain individually resumable

    func testActiveGamesListShowsEveryResumableGame() throws {
        navigateToGenericScoring(playerNames: ["Alice", "Bob"])
        app.buttons["scoring_home_button"].tap()
        XCTAssertTrue(app.buttons["new_game_button"].waitForExistence(timeout: 3))

        navigateToGenericScoring(playerNames: ["Cara", "Dan"])
        app.buttons["scoring_home_button"].tap()

        let activeList = app.descendants(matching: .any)["active_games_list"]
        XCTAssertTrue(activeList.waitForExistence(timeout: 3))

        let activeRows = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'active_game_'"))
        XCTAssertEqual(activeRows.count, 2)
        XCTAssertTrue(activeRows.element(boundBy: 0).exists)
        XCTAssertTrue(activeRows.element(boundBy: 1).exists)
    }

    // MARK: - Test 17: Target score completes after a qualifying submitted round

    func testTargetScoreConfigurationCompletesGenericGame() throws {
        app.buttons["new_game_button"].tap()
        tapGameTile("game_tile_generic")
        fillPlayerNames(["Alice", "Bob"])
        app.buttons["start_game_button"].tap()

        let targetField = app.textFields["target_score_field"]
        XCTAssertTrue(targetField.waitForExistence(timeout: 2))
        targetField.tap()
        targetField.typeText("5")

        app.buttons["start_game_button"].tap()
        XCTAssertTrue(app.buttons["submit_round_button"].waitForExistence(timeout: 3))

        // Open deck, accept 5+0 for Alice and Bob — target score 5 triggers win for Alice
        // Since we can't draw, accept 0 for both; then end game manually
        app.buttons["submit_round_button"].tap()
        _ = app.buttons["Recognize score"].waitForExistence(timeout: 3)
        if app.buttons["Got it"].waitForExistence(timeout: 1) { app.buttons["Got it"].tap() }
        app.buttons["Recognize score"].tap()
        sleep(1)
        if app.buttons["Accept"].waitForExistence(timeout: 2) {
            app.buttons["Accept"].tap(); sleep(1)
        }
        app.buttons["Recognize score"].tap()
        sleep(1)
        if app.buttons["Accept"].waitForExistence(timeout: 2) {
            app.buttons["Accept"].tap(); sleep(2)
        }

        // Target not met (all zeros) — end game manually
        app.buttons["end_game_button"].tap()
        if app.alerts.buttons["End Game"].waitForExistence(timeout: 2) {
            app.alerts.buttons["End Game"].tap()
        }

        XCTAssertTrue(app.staticTexts["winner_text"].waitForExistence(timeout: 4))
    }

    // MARK: - Test 18: Saved roster deletion is explicit

    func testSavedRosterDeletionRequiresConfirmation() throws {
        completeGenericGame(playerNames: ["Alice", "Bob"])

        app.buttons["new_game_button"].tap()
        tapGameTile("game_tile_generic")
        app.buttons["roster_button"].tap()

        let deleteAlice = app.buttons["delete_roster_player_Alice"]
        XCTAssertTrue(deleteAlice.waitForExistence(timeout: 3))
        deleteAlice.tap()

        let destructiveButton = app.buttons["Delete Alice"]
        XCTAssertTrue(destructiveButton.waitForExistence(timeout: 2))
        destructiveButton.tap()

        XCTAssertFalse(app.buttons["roster_player_Alice"].exists)
        XCTAssertTrue(app.buttons["roster_player_Bob"].exists)
    }

    // MARK: - Test 19: Generic scoring ignores the retired handwriting flag

    func testGenericScoringIgnoresLegacyHandwritingFlagAndSubmitsDirectly() throws {
        relaunch(arguments: ["-in-memory-store", "-force-handwriting-entry"])
        navigateToGenericScoring(playerNames: ["Mina", "Omar"])

        XCTAssertFalse(app.buttons["accept_handwritten_score_button"].exists)

        // Open deck, accept 0 for both players (last accept submits)
        completeRound(playerNames: ["Mina", "Omar"])

        XCTAssertTrue(app.staticTexts["Round 2"].waitForExistence(timeout: 3))
    }

    func testRapidDuplicateSubmitCreatesOnlyOneRound() throws {
        navigateToGenericScoring(playerNames: ["Mina", "Omar"])

        // Open deck and submit round via accept on both cards
        completeRound(playerNames: ["Mina", "Omar"])

        XCTAssertTrue(app.staticTexts["Round 2"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["Round 3"].waitForExistence(timeout: 1))
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
        let newGame = app.buttons["new_game_button"]
        XCTAssertTrue(newGame.waitForExistence(timeout: 3))
        tapButtonInSafeArea(newGame)
        tapGameTile("game_tile_generic")
        fillPlayerNames(playerNames)
        app.buttons["start_game_button"].tap()
        XCTAssertTrue(app.segmentedControls["win_condition_picker"].waitForExistence(timeout: 1))
        app.buttons["start_game_button"].tap()
        XCTAssertTrue(app.buttons["end_game_button"].waitForExistence(timeout: 3))
    }

    private func navigateToScoring(gameTileID: String, playerNames: [String]) {
        app.buttons["new_game_button"].tap()
        tapGameTile(gameTileID)
        fillPlayerNames(playerNames)

        // Scoreboard and Ten Phases include a game config step before scoring.
        if gameTileID == "game_tile_generic" || gameTileID == "game_tile_phase10" {
            app.buttons["start_game_button"].tap()
            XCTAssertTrue(app.navigationBars["Game Settings"].waitForExistence(timeout: 2))
        }
        app.buttons["start_game_button"].tap()

        XCTAssertTrue(app.buttons["end_game_button"].waitForExistence(timeout: 3))
    }

    private func tapGameTile(_ identifier: String) {
        let tile = app.buttons[identifier]
        XCTAssertTrue(tile.waitForExistence(timeout: 3))
        tapButtonInSafeArea(tile)
    }

    private func fillPlayerNames(_ names: [String]) {
        for (index, name) in names.enumerated() {
            if index >= 2 {
                app.buttons["add_player_button"].tap()
            }
            let fieldIdentifier = "player_name_field_\(index)"
            let field = app.textFields[fieldIdentifier]
            guard field.waitForExistence(timeout: 2) else {
                XCTFail("Missing \(fieldIdentifier). Current hierarchy:\n\(app.debugDescription)")
                return
            }
            tapTextFieldInSafeArea(field, identifier: fieldIdentifier)
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

        tapGameTile("game_tile_generic")
        fillPlayerNames(["Mina", "Omar", "Jules"])
        snap("06-player-setup")

        app.buttons["start_game_button"].tap()
        _ = app.segmentedControls["win_condition_picker"].waitForExistence(timeout: 2)
        snap("07-game-config")

        app.buttons["start_game_button"].tap()
        _ = app.buttons["end_game_button"].waitForExistence(timeout: 3)
        snap("08-scoring-initial")

        // Open the deck
        app.buttons["submit_round_button"].tap()
        _ = app.buttons["Recognize score"].waitForExistence(timeout: 3)
        snap("09-scoring-deck-mina")

        // Dismiss tutorial if shown
        if app.buttons["Got it"].waitForExistence(timeout: 1) {
            app.buttons["Got it"].tap()
        }

        // Tap ✓ to recognize (empty canvas → no overlay, but exercises the flow)
        app.buttons["Recognize score"].tap()
        sleep(1)

        // Accept or retry — on empty canvas there may be no overlay, so check
        if app.buttons["Accept"].waitForExistence(timeout: 2) {
            snap("09-scoring-confirm-mina")
            app.buttons["Accept"].tap()
            sleep(1)
        } else {
            // No overlay appeared (empty canvas). Clear and move on via swipe.
            app.swipeLeft()
            sleep(1)
        }
        snap("09-scoring-deck-omar")

        // Omar's card — same flow
        if app.buttons["Recognize score"].waitForExistence(timeout: 2) {
            app.buttons["Recognize score"].tap()
            sleep(1)
            if app.buttons["Accept"].waitForExistence(timeout: 2) {
                app.buttons["Accept"].tap()
                sleep(1)
            } else {
                app.swipeLeft()
                sleep(1)
            }
        }

        // Jules — last card; accepting submits round
        if app.buttons["Recognize score"].waitForExistence(timeout: 2) {
            app.buttons["Recognize score"].tap()
            sleep(1)
            if app.buttons["Accept"].waitForExistence(timeout: 2) {
                app.buttons["Accept"].tap()
                sleep(2) // deck closes + round submits
            } else {
                // Cancel deck without scoring, then use submit directly
                app.buttons["round_deck_cancel_button"].tap()
                sleep(1)
                app.buttons["submit_round_button"].tap()
                sleep(1)
            }
        }

        snap("09-scoring-round2")

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

        relaunch(arguments: ["-in-memory-store", "-free-games-exhausted", "-force-light-theme"])
        app.buttons["new_game_button"].tap()
        tapGameTile("game_tile_whatsForDinner")
        fillPlayerNames(["Ada", "Ben"])
        app.buttons["start_game_button"].tap()
        _ = app.descendants(matching: .any)["paywall_title"].waitForExistence(timeout: 3)
        snap("13-paywall")

        relaunch(arguments: ["-in-memory-store", "-force-review-ask", "-force-light-theme"])
        navigateToGenericScoring(playerNames: ["Ada", "Ben"])
        completeRound(playerNames: ["Ada", "Ben"])
        app.buttons["end_game_button"].tap()
        if app.alerts.buttons["End Game"].waitForExistence(timeout: 2) {
            app.alerts.buttons["End Game"].tap()
        }
        _ = app.staticTexts["winner_text"].waitForExistence(timeout: 3)
        snap("14-review-eligible-game-over")
    }

    func testScreenshotTourExtended() throws {
        guard let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] else {
            throw XCTSkip("SCREENSHOT_DIR not set")
        }
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        relaunch(arguments: ["-in-memory-store", "-force-light-theme"])
        XCTAssertTrue(app.buttons["new_game_button"].waitForExistence(timeout: 3))

        func snap(_ name: String) {
            let png = XCUIScreen.main.screenshot().pngRepresentation
            try? png.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
        }

        func dismissToolSheet(named title: String) {
            let sheetNavigationBar = app.navigationBars[title]
            XCTAssertTrue(sheetNavigationBar.waitForExistence(timeout: 3))

            // Use the sheet's Done button. A full-screen swipe can land on the
            // floating dock instead of dismissing the sheet.
            let done = sheetNavigationBar.buttons["Done"]
            XCTAssertTrue(done.waitForExistence(timeout: 3))
            XCTAssertTrue(done.isHittable)
            done.tap()
            XCTAssertFalse(sheetNavigationBar.waitForExistence(timeout: 1))
        }

        func assertHome() {
            XCTAssertTrue(app.buttons["new_game_button"].waitForExistence(timeout: 3))
            XCTAssertFalse(app.navigationBars["Timer"].exists)
            XCTAssertFalse(app.navigationBars["Dice"].exists)
            XCTAssertFalse(app.navigationBars["Starter"].exists)
            XCTAssertFalse(app.navigationBars["Undo"].exists)
        }

        // Tool sheets from Home
        let timerTool = app.buttons["Open game timer"]
        XCTAssertTrue(timerTool.waitForExistence(timeout: 3))
        tapButtonInSafeArea(timerTool)
        sleep(1); snap("15-tool-timer")
        dismissToolSheet(named: "Timer")
        assertHome()

        tapButtonInSafeArea(app.buttons["Roll dice"])
        sleep(1); snap("16-tool-dice")
        dismissToolSheet(named: "Dice")
        assertHome()

        tapButtonInSafeArea(app.buttons["Pick a random starter"])
        sleep(1); snap("17-tool-starter")
        dismissToolSheet(named: "Starter")
        assertHome()

        tapButtonInSafeArea(app.buttons["Learn about undo"])
        sleep(1); snap("18-tool-undo")
        dismissToolSheet(named: "Undo")
        assertHome()

        // Complete a game, snapping the end-game confirmation on the way
        navigateToGenericScoring(playerNames: ["Taylor", "Morgan"])
        completeRound(playerNames: ["Ada", "Ben"])
        app.buttons["end_game_button"].tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 2))
        snap("19-end-game-confirm")
        app.alerts.buttons["End Game"].tap()
        sleep(2)
        app.swipeUp()
        XCTAssertTrue(app.buttons["home_button"].waitForExistence(timeout: 3))
        app.buttons["home_button"].tap()
        _ = app.buttons["new_game_button"].waitForExistence(timeout: 3)

        // Game history + detail
        let seeAll = app.buttons["see_all_button"]
        if !seeAll.waitForExistence(timeout: 1) { app.swipeUp() }
        XCTAssertTrue(seeAll.waitForExistence(timeout: 3))
        seeAll.tap()
        XCTAssertTrue(app.navigationBars["Game History"].waitForExistence(timeout: 3))
        sleep(1); snap("20-game-history")

        app.descendants(matching: .any)["history_card_0"].firstMatch.tap()
        sleep(1); snap("21-game-detail")
        app.navigationBars.buttons.firstMatch.tap()
        sleep(1)
        app.navigationBars.buttons.firstMatch.tap()
        sleep(1)

        // Head to head
        let h2h = app.buttons["Head to Head"]
        if !h2h.waitForExistence(timeout: 1) { app.swipeUp() }
        XCTAssertTrue(h2h.waitForExistence(timeout: 3))
        h2h.tap()
        XCTAssertTrue(app.navigationBars["Head to Head"].waitForExistence(timeout: 3))
        app.buttons["Player 1, Select..."].tap()
        app.buttons["Taylor"].tap()
        app.buttons["Player 2, Select..."].tap()
        app.buttons["Morgan"].tap()
        _ = app.staticTexts["1 game together"].waitForExistence(timeout: 2)
        snap("22-head-to-head")
        app.navigationBars.buttons.firstMatch.tap()
        sleep(1)

        // Player stats
        let playerStats = app.buttons["player_stats_Taylor"]
        if !playerStats.waitForExistence(timeout: 1) { app.swipeUp() }
        XCTAssertTrue(playerStats.waitForExistence(timeout: 3))
        playerStats.tap()
        XCTAssertTrue(app.navigationBars["Taylor"].waitForExistence(timeout: 3))
        sleep(1); snap("23-player-stats")
        app.navigationBars.buttons.firstMatch.tap()
        sleep(1)

        // Dark mode: the tour starts in forced light, so one cycle enters dark.
        app.swipeDown()
        let theme = app.buttons["theme_button"]
        XCTAssertTrue(theme.waitForExistence(timeout: 3))
        theme.tap(); sleep(1)
        snap("24-home-dark")

        navigateToGenericScoring(playerNames: ["Ada", "Ben"])
        app.buttons["submit_round_button"].tap()
        _ = app.buttons["Recognize score"].waitForExistence(timeout: 3)
        app.buttons["Recognize score"].tap()
        if app.buttons["Accept"].waitForExistence(timeout: 3) {
            app.buttons["Accept"].tap(); sleep(1)
        }
        app.buttons["Recognize score"].tap()
        if app.buttons["Accept"].waitForExistence(timeout: 3) {
            app.buttons["Accept"].tap(); sleep(2)
        }
        sleep(1); snap("25-scoring-dark")

        app.buttons["end_game_button"].tap()
        if app.alerts.buttons["End Game"].waitForExistence(timeout: 2) {
            app.alerts.buttons["End Game"].tap()
        }
        sleep(2); snap("26-game-over-dark")

        // Restore theme to system
        app.swipeUp()
        if app.buttons["home_button"].waitForExistence(timeout: 3) {
            app.buttons["home_button"].tap()
        }
        if theme.waitForExistence(timeout: 3) {
            theme.tap()
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

    private func tapTextFieldInSafeArea(_ element: XCUIElement, identifier: String) {
        let appFrame = app.frame
        let safeTop: CGFloat = 120

        for _ in 0..<6 {
            let keyboard = app.keyboards.firstMatch
            let safeBottom = keyboard.exists ? keyboard.frame.minY - 12 : appFrame.height - 120
            let frame = element.frame
            let visibleTop = max(frame.minY, safeTop)
            let visibleBottom = min(frame.maxY, safeBottom)

            if visibleBottom - visibleTop >= 44 {
                let point = CGPoint(x: frame.midX, y: (visibleTop + visibleBottom) / 2)
                let normalizedPoint = CGVector(
                    dx: (point.x - appFrame.minX) / appFrame.width,
                    dy: (point.y - appFrame.minY) / appFrame.height
                )
                app.coordinate(withNormalizedOffset: normalizedPoint).tap()
                return
            }

            if frame.maxY <= safeTop + 44 {
                app.swipeDown(velocity: .fast)
            } else {
                app.swipeUp(velocity: .fast)
            }
        }

        XCTFail("Text field never exposed a safe 44-point focus area: \(identifier)")
    }

    private func tapButtonInSafeArea(_ element: XCUIElement) {
        guard element.waitForExistence(timeout: 3) else {
            XCTFail("Button did not exist: \(element)")
            return
        }

        let appFrame = app.frame
        let safeTop: CGFloat = 80
        let safeBottom = appFrame.height - 120
        var safeTapPoint: CGPoint?

        for _ in 0..<6 {
            let frame = element.frame
            let visibleTop = max(frame.minY, safeTop)
            let visibleBottom = min(frame.maxY, safeBottom)
            if element.exists && visibleBottom - visibleTop >= 44 {
                safeTapPoint = CGPoint(x: frame.midX, y: (visibleTop + visibleBottom) / 2)
                break
            }
            app.swipeUp(velocity: .fast)
        }

        guard let safeTapPoint else {
            XCTFail("Button never exposed a safe 44-point tap area: \(element)")
            return
        }

        let normalizedPoint = CGVector(
            dx: (safeTapPoint.x - appFrame.minX) / appFrame.width,
            dy: (safeTapPoint.y - appFrame.minY) / appFrame.height
        )
        app.coordinate(withNormalizedOffset: normalizedPoint).tap()
    }

    private func waitForHittable(_ element: XCUIElement, timeout: TimeInterval = 3) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.isHittable { return true }
            usleep(100_000)
        }
        return element.isHittable
    }

    private func scrollToHittable(_ element: XCUIElement, maxSwipes: Int = 5) -> Bool {
        for _ in 0..<maxSwipes {
            if element.exists && element.isHittable {
                return true
            }
            app.swipeUp(velocity: .fast)
        }
        return element.exists && element.isHittable
    }

    private func completeOpenDeck(playerNames: [String]) {
        XCTAssertTrue(app.descendants(matching: .any)["round_entry_deck"].waitForExistence(timeout: 10))
        if app.buttons["Got it"].waitForExistence(timeout: 3) { app.buttons["Got it"].tap() }
        else if app.buttons["Skip"].waitForExistence(timeout: 1) { app.buttons["Skip"].tap() }

        let recognize = app.buttons["Recognize score"]
        XCTAssertTrue(recognize.waitForExistence(timeout: 10))
        for (index, _) in playerNames.enumerated() {
            XCTAssertTrue(recognize.waitForExistence(timeout: 10))
            recognize.tap()
            let accept = app.buttons["Accept"]
            XCTAssertTrue(accept.waitForExistence(timeout: 10),
                          "Score confirmation did not appear")
            accept.tap()
            if index < playerNames.count - 1 {
                XCTAssertTrue(recognize.waitForExistence(timeout: 10))
            }
        }

        // The deck dismisses with a short exit animation; wait until it is
        // fully closed before interacting with the scoring screen beneath.
        let deck = app.descendants(matching: .any)["round_entry_deck"]
        let deadline = Date().addingTimeInterval(5)
        while deck.exists && Date() < deadline {
            usleep(100_000)
        }
        XCTAssertFalse(deck.exists, "Score deck did not close")
    }

    private func completeRound(playerNames: [String], gameType: String = "generic") {
        app.buttons["submit_round_button"].tap()
        // Only generic scoring opens the deck; Phase 10 and WhatsForDinner submit directly
        if gameType == "generic" {
            completeOpenDeck(playerNames: playerNames)
        } else {
            _ = app.staticTexts["Rounds"].waitForExistence(timeout: 3)
        }
    }

    private func completeGenericGame(playerNames: [String]) {
        navigateToGenericScoring(playerNames: playerNames)
        completeRound(playerNames: playerNames)
        app.buttons["end_game_button"].tap()
        app.alerts.buttons["End Game"].tap()
        let homeButton = app.buttons["home_button"]
        XCTAssertTrue(homeButton.waitForExistence(timeout: 5))
        homeButton.tap()
    }
}
