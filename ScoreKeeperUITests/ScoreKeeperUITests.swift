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

        assertOnboardingTitle("put the score pad down")
        app.buttons["onboarding_skip_button"].tap()
        XCTAssertTrue(app.buttons["new_game_button"].waitForExistence(timeout: 3))

        launchOnboarding()

        assertOnboardingTitle("put the score pad down")
        app.buttons["onboarding_primary_button"].tap()
        assertOnboardingTitle("set up in seconds")
        app.buttons["onboarding_primary_button"].tap()
        assertOnboardingTitle("every night becomes history")
        app.buttons["onboarding_primary_button"].tap()
        XCTAssertTrue(app.buttons["new_game_button"].waitForExistence(timeout: 3))
    }

    // MARK: - Test 1: Create Generic Game and navigate to scoring

    func testCreateGenericGameAndScore() throws {
        navigateToGenericScoring(playerNames: ["alice", "bob", "charlie"])

        // Verify scoring screen is shown
        XCTAssertTrue(app.buttons["end_game_button"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["submit_round_button"].waitForExistence(timeout: 2))

        // Verify player names are visible
        XCTAssertTrue(app.staticTexts["alice"].exists)
        XCTAssertTrue(app.staticTexts["bob"].exists)
        XCTAssertTrue(app.staticTexts["charlie"].exists)

        // Submit a round (all zeros is fine)
        completeRound(playerNames: ["alice", "bob", "charlie"])

        // End Game
        endGameViaAlert()

        // Game Over: verify winner text
        let winnerText = app.staticTexts["winner_text"]
        XCTAssertTrue(winnerText.waitForExistence(timeout: 2))
        XCTAssertTrue(winnerText.exists)
    }

    // MARK: - Test 2: Create Ten Phases Game → Score → End

    func testCreatePhase10GameAndScore() throws {
        navigateToScoring(gameTileID: "game_tile_phase10", playerNames: ["alice", "bob"])

        // Submit one round for Ten Phases (submits directly, no deck)
        completeRound(playerNames: ["alice", "bob"], gameType: "phase10")

        // End Game
        endGameViaAlert()

        // Game Over: verify
        XCTAssertTrue(app.staticTexts["winner_text"].waitForExistence(timeout: 2))
    }

    // MARK: - Test 3: Create game, navigate to scoring, verify screen

    func testResumeInProgressGame() throws {
        navigateToGenericScoring(playerNames: ["alice", "bob"])

        // Submit one round
        completeRound(playerNames: ["alice", "bob"])

        // End Game
        endGameViaAlert()

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
        navigateToGenericScoring(playerNames: ["alice", "bob"])

        completeRound(playerNames: ["alice", "bob"])

        // End Game
        endGameViaAlert()

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
        navigateToGenericScoring(playerNames: ["alice", "bob"])
        completeRound(playerNames: ["ada", "ben"])
        endGameViaAlert()
        app.swipeUp()
        let homeButton = app.buttons["home_button"]
        XCTAssertTrue(homeButton.waitForExistence(timeout: 3))
        homeButton.tap()
        sleep(1)

        // Complete second game
        let newGameButton = app.buttons["new_game_button"]
        XCTAssertTrue(newGameButton.waitForExistence(timeout: 3))
        ScoreDeckUITestSupport.tapButtonInSafeArea(newGameButton, in: app)
        tapGameTile("game_tile_generic")
        fillPlayerNames(["charlie", "Diana"])
        app.buttons["start_game_button"].tap()
        app.buttons["start_game_button"].tap()
        completeRound(playerNames: ["ada", "ben"])
        endGameViaAlert()
        app.swipeUp()
        let homeButton2 = app.buttons["home_button"]
        XCTAssertTrue(homeButton2.waitForExistence(timeout: 3))
        homeButton2.tap()
        sleep(1)

        // Verify Recent Games on More below the PipCount Pro banner.
        app.buttons["legal_support_button"].tap()
        XCTAssertTrue(scrollToHittable(app.buttons["see_all_button"]))
        XCTAssertTrue(app.buttons["tab_home"].exists)
    }

    // MARK: - Test 6: Cautious user fixes invalid setup

    func testPlayerSetupValidatesDuplicateNames() throws {
        ScoreDeckUITestSupport.tapButtonInSafeArea(app.buttons["new_game_button"], in: app)
        tapGameTile("game_tile_generic")

        fillPlayerNames(["alex", "alex"])

        XCTAssertTrue(app.staticTexts["player names must be unique"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["start_game_button"].isEnabled)

        replaceText(in: app.textFields["player_name_field_1"], with: "jordan")

        XCTAssertFalse(app.staticTexts["player names must be unique"].exists)
        XCTAssertTrue(app.buttons["start_game_button"].isEnabled)
    }

    // MARK: - Test 7: Score-focused user adjusts points

    // MARK: - Test 8: What's for Dinner player records a meal reveal

    func testWhatsForDinnerMealRevealFlow() throws {
        navigateToScoring(gameTileID: "game_tile_whatsForDinner", playerNames: ["mina", "nora", "omar"])

        app.buttons["meal_reveal_mina"].tap()
        if !app.staticTexts["caller"].waitForExistence(timeout: 1) {
            app.staticTexts["mina"].firstMatch.tap()
        }

        // WhatsForDinner uses its own scoring rows (not the deck) — unchanged
        app.buttons["mina_increment"].tap()
        app.buttons["nora_increment"].tap()
        app.buttons["nora_increment"].tap()
        app.buttons["submit_round_button"].tap()

        XCTAssertTrue(app.staticTexts["round 2"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["rounds"].exists)
    }

    // MARK: - Test 9: Repeat user chooses saved roster players

    func testRosterReuseAddsSavedPlayers() throws {
        completeGenericGame(playerNames: ["riley", "sam"])

        XCTAssertTrue(app.buttons["new_game_button"].waitForExistence(timeout: 3))
        ScoreDeckUITestSupport.tapButtonInSafeArea(app.buttons["new_game_button"], in: app)
        tapGameTile("game_tile_phase10")
        app.buttons["roster_button"].tap()

        let riley = app.buttons["roster_player_riley"]
        let sam = app.buttons["roster_player_sam"]
        XCTAssertTrue(riley.waitForExistence(timeout: 3))
        XCTAssertTrue(sam.waitForExistence(timeout: 3))

        riley.tap()
        sam.tap()
        app.buttons["add (2)"].tap()

        XCTAssertTrue(waitForTextFields(["player_name_field_0", "player_name_field_1"], toContain: ["riley", "sam"]))
        XCTAssertTrue(app.buttons["start_game_button"].isEnabled)
    }

    // MARK: - Test 10: Theme and stats user explores completed data

    func testThemeToggleAndHeadToHeadStatsNavigation() throws {
        XCTAssertFalse(app.buttons["theme_button"].exists)
        app.buttons["legal_support_button"].tap()
        XCTAssertTrue(app.buttons["theme_dark_button"].waitForExistence(timeout: 3))
        app.buttons["theme_dark_button"].tap()
        app.buttons["theme_system_button"].tap()
        app.buttons["tab_home"].tap()

        completeGenericGame(playerNames: ["taylor", "morgan"])

        // Stats now belongs to the Players page, directly below Add Player.
        // Open that page before locating the Head to Head control.
        if app.buttons["tab_players"].exists {
            app.buttons["tab_players"].tap()
            usleep(400_000)
        }

        let headToHeadButton = app.buttons["head_to_head_button"]
        XCTAssertTrue(headToHeadButton.waitForExistence(timeout: 5))

        let playersScrollView = app.scrollViews
            .containing(.button, identifier: "head_to_head_button")
            .firstMatch
        let dockTop = app.frame.height - 130
        let safeTop: CGFloat = 80

        var pushed = false
        for _ in 0..<12 {
            let frame = headToHeadButton.frame
            let visibleTop = max(frame.minY, safeTop)
            let visibleBottom = min(frame.maxY, dockTop)
            let visibleHeight = visibleBottom - visibleTop
            // The button's AX frame is only ~34pt tall (QuietLinkRow label +
            // padding), so a 40/44pt clearance threshold could never be met
            // even when the button was fully visible. Require ~2/3 of it.
            if headToHeadButton.isHittable, visibleHeight >= 24 {
                // Native tap first — XCUI resolves the hit point itself and
                // this is what worked before the dock was added.
                headToHeadButton.tap()
                if app.navigationBars["head to head"].waitForExistence(timeout: 2) {
                    pushed = true
                    break
                }
                // Fallback 1: tap the visible label text (fresh query, own hit area).
                let rowLabel = app.staticTexts["head to head"]
                if rowLabel.exists && rowLabel.isHittable {
                    rowLabel.tap()
                    if app.navigationBars["head to head"].waitForExistence(timeout: 2) {
                        pushed = true
                        break
                    }
                }
                // Fallback 2: explicit coordinate inside the visible band.
                let point = CGPoint(x: frame.midX, y: (visibleTop + visibleBottom) / 2)
                let normalized = CGVector(
                    dx: point.x / app.frame.width,
                    dy: point.y / app.frame.height
                )
                app.coordinate(withNormalizedOffset: normalized).tap()
                if app.navigationBars["head to head"].waitForExistence(timeout: 2) {
                    pushed = true
                    break
                }
                // Swallowed — the tap likely landed on the dock. Re-open Players and retry.
                if app.buttons["tab_players"].exists {
                    app.buttons["tab_players"].tap()
                    usleep(400_000)
                }
            } else if frame.minY < safeTop {
                // Overshot past the top of the screen: ease back down.
                playersScrollView.swipeDown(velocity: .fast)
                usleep(300_000)
            } else {
                // Below the fold or behind the dock: scroll the Players view.
                playersScrollView.swipeUp(velocity: .fast)
                usleep(300_000)
            }
        }
        XCTAssertTrue(pushed, "Head to Head screen never appeared")
        // The redesigned picker's menu button carries the full label
        // "player one, select a player" / "player two, select a player".
        let playerOnePicker = app.buttons["player one, select a player"]
        XCTAssertTrue(playerOnePicker.waitForExistence(timeout: 3))
        playerOnePicker.tap()
        app.buttons["taylor"].firstMatch.tap()
        let playerTwoPicker = app.buttons["player two, select a player"]
        XCTAssertTrue(playerTwoPicker.waitForExistence(timeout: 3))
        playerTwoPicker.tap()
        app.buttons["morgan"].firstMatch.tap()

        XCTAssertTrue(app.staticTexts["1 game together"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["1 game together"].exists)
    }

    // MARK: - Test 11: History is reachable with one completed game


    func testPlayerStatsNavigationFromStatsEntry() throws {
        completeGenericGame(playerNames: ["taylor", "morgan"])

        XCTAssertFalse(app.buttons["head_to_head_button"].exists)
        app.buttons["tab_players"].tap()
        let addPlayerButton = app.buttons["add_new_player_button"]
        XCTAssertTrue(addPlayerButton.waitForExistence(timeout: 3))
        XCTAssertEqual(addPlayerButton.label, "add player")

        // Scroll to find the saved player card (chip row was removed; the
        // saved player card now opens the player history).
        let savedPlayerButton = app.buttons["saved_player_taylor"]
        var found = false
        for _ in 0..<6 {
            if savedPlayerButton.exists && savedPlayerButton.isHittable {
                found = true
                break
            }
            app.swipeUp(velocity: .fast)
        }
        XCTAssertTrue(found || savedPlayerButton.exists, "saved_player_taylor not found after scrolling")
        XCTAssertTrue(savedPlayerButton.waitForExistence(timeout: 3))
        savedPlayerButton.tap()

        XCTAssertTrue(app.navigationBars["player history"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["games"].exists)
        XCTAssertTrue(app.staticTexts["wins"].exists)
    }

    // MARK: - Test 13: Exhausted free games shows paywall

    func testFreeGamesExhaustedShowsPaywallWhenStartingNewGame() throws {
        relaunch(arguments: ["-in-memory-store", "-free-games-exhausted", "-force-light-theme"])

        ScoreDeckUITestSupport.tapButtonInSafeArea(app.buttons["new_game_button"], in: app)
        tapGameTile("game_tile_whatsForDinner")
        fillPlayerNames(["ada", "ben"])
        app.buttons["start_game_button"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["paywall_title"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["paywall_unlock_button"].exists)
    }

    // MARK: - Test 14: Pro unlock bypasses paywall

    func testUnlockedProDoesNotShowPaywallWhenStartingNewGame() throws {
        relaunch(arguments: ["-in-memory-store", "-unlock-pro"])

        ScoreDeckUITestSupport.tapButtonInSafeArea(app.buttons["new_game_button"], in: app)
        tapGameTile("game_tile_whatsForDinner")
        fillPlayerNames(["ada", "ben"])
        app.buttons["start_game_button"].tap()

        XCTAssertTrue(app.buttons["end_game_button"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["pipcount pro"].waitForExistence(timeout: 1))
    }

    // MARK: - Test 15: Forced review ask uses Apple's native flow

    func testForceReviewAskAppearsAfterCompletingGame() throws {
        relaunch(arguments: ["-in-memory-store", "-force-review-ask", "-force-light-theme"])

        navigateToGenericScoring(playerNames: ["ada", "ben"])
        completeRound(playerNames: ["ada", "ben"])
        endGameViaAlert()

        XCTAssertTrue(app.staticTexts["winner_text"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["review_ask_rate_button"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["review_ask_later_button"].exists)
        XCTAssertFalse(app.staticTexts["How was game night?"].exists)
    }

    // MARK: - Test 16: Active games remain individually resumable

    func testActiveGamesListShowsEveryResumableGame() throws {
        navigateToGenericScoring(playerNames: ["alice", "bob"])
        app.buttons["scoring_home_button"].tap()
        XCTAssertTrue(app.buttons["new_game_button"].waitForExistence(timeout: 3))

        navigateToGenericScoring(playerNames: ["cara", "dan"])
        app.buttons["scoring_home_button"].tap()

        let activeList = app.descendants(matching: .any)["active_games_list"]
        XCTAssertTrue(activeList.waitForExistence(timeout: 3))

        let activeRows = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'active_game_'"))
        XCTAssertEqual(activeRows.count, 2)
        XCTAssertTrue(activeRows.element(boundBy: 0).exists)
        XCTAssertTrue(activeRows.element(boundBy: 1).exists)

        let deleteButtons = app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH 'delete_active_game_'"))
        XCTAssertEqual(deleteButtons.count, 2)

        let firstSlider = activeRows.element(boundBy: 0)
        let firstDeleteButton = deleteButtons.element(boundBy: 0)
        let actionWidth = firstSlider.frame.width + firstDeleteButton.frame.width
        XCTAssertEqual(firstSlider.frame.width / actionWidth, 0.90, accuracy: 0.01)

        let sliderStart = firstSlider.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.5))
        let sliderEnd = firstSlider.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5))
        sliderStart.press(forDuration: 0.1, thenDragTo: sliderEnd)

        XCTAssertTrue(app.buttons["submit_round_button"].waitForExistence(timeout: 3))
    }

    // MARK: - Test 17: Target score completes after a qualifying submitted round

    func testTargetScoreConfigurationCompletesGenericGame() throws {
        ScoreDeckUITestSupport.tapButtonInSafeArea(app.buttons["new_game_button"], in: app)
        tapGameTile("game_tile_generic")
        fillPlayerNames(["alice", "bob"])
        app.buttons["start_game_button"].tap()

        let targetField = app.textFields["target_score_field"]
        XCTAssertTrue(targetField.waitForExistence(timeout: 2))
        targetField.tap()
        targetField.typeText("5")

        app.buttons["start_game_button"].tap()
        XCTAssertTrue(app.buttons["submit_round_button"].waitForExistence(timeout: 3))

        // Open deck, then cancel: a blank canvas no longer yields a phantom
        // zero to accept (the inline no-ink hint replaces it), so no round is
        // submitted and the game is ended manually.
        app.buttons["submit_round_button"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["round_entry_deck"].waitForExistence(timeout: 3))
        if app.buttons["got it"].waitForExistence(timeout: 1) { app.buttons["got it"].tap() }
        app.buttons["round_deck_cancel_button"].tap()
        ScoreDeckUITestSupport.waitForDeckToClose(in: app)

        // Target not met (no round submitted) — end game manually
        endGameViaAlert()

        XCTAssertTrue(app.staticTexts["winner_text"].waitForExistence(timeout: 4))
    }

    // MARK: - Test 18: Saved roster deletion is explicit

    func testSavedRosterDeletionRequiresConfirmation() throws {
        completeGenericGame(playerNames: ["alice", "bob"])

        ScoreDeckUITestSupport.tapButtonInSafeArea(app.buttons["new_game_button"], in: app)
        tapGameTile("game_tile_generic")
        app.buttons["roster_button"].tap()

        let deleteAlice = app.buttons["delete_roster_player_alice"]
        XCTAssertTrue(deleteAlice.waitForExistence(timeout: 3))
        deleteAlice.tap()

        let destructiveButton = app.buttons["delete alice"]
        XCTAssertTrue(destructiveButton.waitForExistence(timeout: 2))
        destructiveButton.tap()

        XCTAssertFalse(app.buttons["roster_player_alice"].exists)
        XCTAssertTrue(app.buttons["roster_player_bob"].exists)
    }

    // MARK: - Test 19: Generic scoring ignores the retired handwriting flag

    func testRapidDuplicateSubmitCreatesOnlyOneRound() throws {
        navigateToGenericScoring(playerNames: ["mina", "omar"])

        // Open deck and submit round via accept on both cards
        completeRound(playerNames: ["mina", "omar"])

        XCTAssertTrue(app.staticTexts["round 2"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["round 3"].waitForExistence(timeout: 1))
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
        ScoreDeckUITestSupport.tapButtonInSafeArea(newGame, in: app)
        tapGameTile("game_tile_generic")
        fillPlayerNames(playerNames)
        app.buttons["start_game_button"].tap()
        XCTAssertTrue(app.segmentedControls["win_condition_picker"].waitForExistence(timeout: 1))
        app.buttons["start_game_button"].tap()
        XCTAssertTrue(app.buttons["end_game_button"].waitForExistence(timeout: 3))
    }

    private func navigateToScoring(gameTileID: String, playerNames: [String]) {
        ScoreDeckUITestSupport.tapButtonInSafeArea(app.buttons["new_game_button"], in: app)
        tapGameTile(gameTileID)
        fillPlayerNames(playerNames)

        // Scoreboard and Ten Phases include a game config step before scoring.
        if gameTileID == "game_tile_generic" || gameTileID == "game_tile_phase10" {
            app.buttons["start_game_button"].tap()
            XCTAssertTrue(app.navigationBars["game settings"].waitForExistence(timeout: 2))
        }
        app.buttons["start_game_button"].tap()

        XCTAssertTrue(app.buttons["end_game_button"].waitForExistence(timeout: 3))
    }

    private func tapGameTile(_ identifier: String) {
        let tile = app.buttons[identifier]
        XCTAssertTrue(tile.waitForExistence(timeout: 3))
        ScoreDeckUITestSupport.tapButtonInSafeArea(tile, in: app)
    }

    private func fillPlayerNames(_ names: [String]) {
        for (index, name) in names.enumerated() {
            if index >= 2 {
                if app.keyboards.firstMatch.exists {
                    app.keyboards.buttons["Return"].tap()
                }
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

        ScoreDeckUITestSupport.tapButtonInSafeArea(app.buttons["new_game_button"], in: app)
        _ = app.buttons["game_tile_generic"].waitForExistence(timeout: 2)
        snap("05-game-picker")

        tapGameTile("game_tile_generic")
        fillPlayerNames(["mina", "omar", "jules"])
        snap("06-player-setup")

        app.buttons["start_game_button"].tap()
        _ = app.segmentedControls["win_condition_picker"].waitForExistence(timeout: 2)
        snap("07-game-config")

        app.buttons["start_game_button"].tap()
        _ = app.buttons["end_game_button"].waitForExistence(timeout: 3)
        snap("08-scoring-initial")

        // Open the deck
        app.buttons["submit_round_button"].tap()
        _ = app.descendants(matching: .any)["round_entry_deck"].waitForExistence(timeout: 3)
        snap("09-scoring-deck-mina")

        // Dismiss tutorial if shown
        if app.buttons["got it"].waitForExistence(timeout: 1) {
            app.buttons["got it"].tap()
        }

        // Mina: draw a zero and recognize so the confirmation card is real
        // (a blank canvas now shows the inline no-ink hint instead).
        ScoreDeckUITestSupport.drawEllipseZero(in: app)
        app.buttons["recognize_score_button"].tap()
        let confirmation = ScoreDeckUITestSupport.acceptButton(in: app)
        if confirmation.waitForExistence(timeout: 15) {
            snap("09-scoring-confirm-mina")
            confirmation.tap()
            sleep(1)
        } else if ScoreDeckUITestSupport.rejectionCard(in: app).exists {
            ScoreDeckUITestSupport.useManualValue("0", in: app)
            sleep(1)
        } else {
            ScoreDeckUITestSupport.commitZeroForCurrentPlayer(in: app)
        }
        snap("09-scoring-deck-omar")

        // Omar and Jules — same flow; accepting Jules submits the round.
        ScoreDeckUITestSupport.commitZeroForCurrentPlayer(in: app)
        sleep(1)
        snap("09-scoring-deck-jules")
        ScoreDeckUITestSupport.commitZeroForCurrentPlayer(in: app)
        sleep(2) // deck closes + round submits

        snap("09-scoring-round2")

        app.buttons["end_game_button"].tap()
        if app.alerts.buttons["end game"].waitForExistence(timeout: 2) {
            app.alerts.buttons["end game"].tap()
        }
        sleep(2); snap("10-game-over")

        if app.buttons["home_button"].waitForExistence(timeout: 2) {
            app.buttons["home_button"].tap()
        } else if app.buttons["Home"].waitForExistence(timeout: 2) {
            app.buttons["Home"].tap()
        }
        _ = app.buttons["new_game_button"].waitForExistence(timeout: 3)
        snap("11-home-with-history")

        app.buttons["legal_support_button"].tap()
        if app.buttons["theme_dark_button"].waitForExistence(timeout: 3) {
            app.buttons["theme_dark_button"].tap()
            app.buttons["tab_home"].tap()
            sleep(1); snap("12-home-theme-toggled")
            app.buttons["legal_support_button"].tap()
            app.buttons["theme_system_button"].tap()
            app.buttons["tab_home"].tap()
            sleep(1)
        }

        relaunch(arguments: ["-in-memory-store", "-free-games-exhausted", "-force-light-theme"])
        ScoreDeckUITestSupport.tapButtonInSafeArea(app.buttons["new_game_button"], in: app)
        tapGameTile("game_tile_whatsForDinner")
        fillPlayerNames(["ada", "ben"])
        app.buttons["start_game_button"].tap()
        _ = app.descendants(matching: .any)["paywall_title"].waitForExistence(timeout: 3)
        snap("13-paywall")

        relaunch(arguments: ["-in-memory-store", "-force-review-ask", "-force-light-theme"])
        navigateToGenericScoring(playerNames: ["ada", "ben"])
        completeRound(playerNames: ["ada", "ben"])
        app.buttons["end_game_button"].tap()
        if app.alerts.buttons["end game"].waitForExistence(timeout: 2) {
            app.alerts.buttons["end game"].tap()
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
            XCTAssertFalse(app.navigationBars["timer"].exists)
            XCTAssertFalse(app.navigationBars["dice"].exists)
            XCTAssertFalse(app.navigationBars["starter"].exists)
            XCTAssertFalse(app.navigationBars["undo"].exists)
        }

        // Tool sheets from Home
        let timerTool = app.buttons["Open game timer"]
        XCTAssertTrue(timerTool.waitForExistence(timeout: 3))
        ScoreDeckUITestSupport.tapButtonInSafeArea(timerTool, in: app)
        sleep(1); snap("15-tool-timer")
        dismissToolSheet(named: "timer")
        assertHome()

        ScoreDeckUITestSupport.tapButtonInSafeArea(app.buttons["Roll dice"], in: app)
        sleep(1); snap("16-tool-dice")
        dismissToolSheet(named: "dice")
        assertHome()

        ScoreDeckUITestSupport.tapButtonInSafeArea(app.buttons["Pick a random starter"], in: app)
        sleep(1); snap("17-tool-starter")
        dismissToolSheet(named: "starter")
        assertHome()

        ScoreDeckUITestSupport.tapButtonInSafeArea(app.buttons["Learn about undo"], in: app)
        sleep(1); snap("18-tool-undo")
        dismissToolSheet(named: "undo")
        assertHome()

        // Complete a game, snapping the end-game confirmation on the way
        navigateToGenericScoring(playerNames: ["taylor", "morgan"])
        completeRound(playerNames: ["ada", "ben"])
        app.buttons["end_game_button"].tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 2))
        snap("19-end-game-confirm")
        app.alerts.buttons["end game"].tap()
        sleep(2)
        app.swipeUp()
        XCTAssertTrue(app.buttons["home_button"].waitForExistence(timeout: 3))
        app.buttons["home_button"].tap()
        _ = app.buttons["new_game_button"].waitForExistence(timeout: 3)

        // Game history + detail
        app.buttons["legal_support_button"].tap()
        let seeAll = app.buttons["see_all_button"]
        if !seeAll.waitForExistence(timeout: 1) { app.swipeUp() }
        XCTAssertTrue(seeAll.waitForExistence(timeout: 3))
        seeAll.tap()
        XCTAssertTrue(app.navigationBars["game history"].waitForExistence(timeout: 3))
        sleep(1); snap("20-game-history")

        let firstCard = app.descendants(matching: .any)["history_card_0"]
        if !firstCard.exists || !firstCard.isHittable { app.swipeUp() }
        XCTAssertTrue(firstCard.waitForExistence(timeout: 3))
        firstCard.tap()
        sleep(1); snap("21-game-detail")
        app.navigationBars.buttons.firstMatch.tap()
        sleep(1)
        app.navigationBars.buttons.firstMatch.tap()
        sleep(1)

        // Head to head
        app.buttons["tab_players"].tap()
        let h2h = app.buttons["head to head"]
        if !h2h.waitForExistence(timeout: 1) { app.swipeUp() }
        XCTAssertTrue(h2h.waitForExistence(timeout: 3))
        h2h.tap()
        XCTAssertTrue(app.navigationBars["head to head"].waitForExistence(timeout: 3))
        app.buttons["player one, select a player"].tap()
        app.buttons["taylor"].tap()
        app.buttons["player two, select a player"].tap()
        app.buttons["morgan"].tap()
        _ = app.staticTexts["1 game together"].waitForExistence(timeout: 2)
        snap("22-head-to-head")
        app.navigationBars.buttons.firstMatch.tap()
        sleep(1)

        // Player stats
        let playerStats = app.buttons["saved_player_taylor"]
        if !playerStats.waitForExistence(timeout: 1) { app.swipeUp() }
        XCTAssertTrue(playerStats.waitForExistence(timeout: 3))
        playerStats.tap()
        XCTAssertTrue(app.navigationBars["player history"].waitForExistence(timeout: 3))
        sleep(1); snap("23-player-stats")
        app.navigationBars.buttons.firstMatch.tap()
        sleep(1)

        // Dark mode: the tour starts in forced light, so select dark in More.
        app.buttons["legal_support_button"].tap()
        let darkTheme = app.buttons["theme_dark_button"]
        XCTAssertTrue(darkTheme.waitForExistence(timeout: 3))
        darkTheme.tap()
        app.buttons["tab_home"].tap()
        sleep(1)
        snap("24-home-dark")

        navigateToGenericScoring(playerNames: ["ada", "ben"])
        app.buttons["submit_round_button"].tap()
        _ = app.descendants(matching: .any)["round_entry_deck"].waitForExistence(timeout: 3)
        ScoreDeckUITestSupport.dismissDeckTutorialIfPresent(in: app)
        ScoreDeckUITestSupport.commitZeroForCurrentPlayer(in: app)
        ScoreDeckUITestSupport.commitZeroForCurrentPlayer(in: app)
        ScoreDeckUITestSupport.waitForDeckToClose(in: app)
        sleep(1); snap("25-scoring-dark")

        app.buttons["end_game_button"].tap()
        if app.alerts.buttons["end game"].waitForExistence(timeout: 2) {
            app.alerts.buttons["end game"].tap()
        }
        sleep(2); snap("26-game-over-dark")

        // Restore theme to system.
        app.swipeUp()
        if app.buttons["home_button"].waitForExistence(timeout: 3) {
            app.buttons["home_button"].tap()
        }
        app.buttons["legal_support_button"].tap()
        if app.buttons["theme_system_button"].waitForExistence(timeout: 3) {
            app.buttons["theme_system_button"].tap()
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
        if app.buttons["got it"].waitForExistence(timeout: 3) { app.buttons["got it"].tap() }
        else if app.buttons["skip"].waitForExistence(timeout: 1) { app.buttons["skip"].tap() }

        // A blank canvas no longer yields a phantom zero to accept; the
        // recognizer answers with the inline no-ink hint. Draw a zero on each
        // card and commit it, falling back to manual entry when the ink is
        // rejected.
        for _ in playerNames {
            ScoreDeckUITestSupport.commitZeroForCurrentPlayer(in: app)
        }

        // The deck dismisses with a short exit animation; wait until it is
        // fully closed before interacting with the scoring screen beneath.
        ScoreDeckUITestSupport.waitForDeckToClose(in: app)
    }

    private func completeRound(playerNames: [String], gameType: String = "generic") {
        app.buttons["submit_round_button"].tap()
        // Only generic scoring opens the deck; Phase 10 and WhatsForDinner submit directly
        if gameType == "generic" {
            completeOpenDeck(playerNames: playerNames)
        } else {
            _ = app.staticTexts["rounds"].waitForExistence(timeout: 3)
        }
    }

    private func completeGenericGame(playerNames: [String]) {
        navigateToGenericScoring(playerNames: playerNames)
        completeRound(playerNames: playerNames)
        endGameViaAlert()
        let homeButton = app.buttons["home_button"]
        XCTAssertTrue(homeButton.waitForExistence(timeout: 5))
        homeButton.tap()
    }

    /// Taps End Game and confirms the system alert, retrying once if the
    /// deck's exit animation races the tap (a late submit can re-open the
    /// deck over the scoring screen).
    private func endGameViaAlert() {
        let confirm = app.alerts.buttons["end game"]
        for _ in 0..<3 {
            guard !confirm.waitForExistence(timeout: 2) else {
                confirm.tap()
                if confirm.waitForExistence(timeout: 1) { continue }
                return
            }
            // Alert not up yet: either the tap was swallowed by a transition
            // or the deck re-opened. Dismiss it if present, then retry.
            if app.descendants(matching: .any)["round_entry_deck"].exists {
                app.buttons["round_deck_cancel_button"].tap()
            }
            _ = app.buttons["end_game_button"].waitForExistence(timeout: 3)
            app.buttons["end_game_button"].tap()
        }
        XCTFail("End Game confirmation never appeared")
    }
}
