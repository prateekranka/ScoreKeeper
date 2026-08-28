import XCTest

@MainActor
enum ScoreDeckUITestSupport {
    static func dismissDeckTutorialIfPresent(in app: XCUIApplication) {
        if app.buttons["Got it"].waitForExistence(timeout: 2) {
            app.buttons["Got it"].tap()
        } else if app.buttons["Skip"].waitForExistence(timeout: 1) {
            app.buttons["Skip"].tap()
        }
    }

    static func tapButtonInSafeArea(
        _ element: XCUIElement,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let sidebarNewGame = app.buttons["sidebar_new_game_button"]
        let target = element.identifier == "new_game_button" && sidebarNewGame.exists
            ? sidebarNewGame
            : element

        guard target.waitForExistence(timeout: 3) else {
            XCTFail("Button did not exist: \(target)", file: file, line: line)
            return
        }

        let appFrame = app.frame
        let safeTop: CGFloat = 80
        let safeBottom = appFrame.height - 120
        var safeTapPoint: CGPoint?

        for _ in 0..<6 {
            let frame = target.frame
            let visibleTop = max(frame.minY, safeTop)
            let visibleBottom = min(frame.maxY, safeBottom)
            if target.exists && visibleBottom - visibleTop >= 44 {
                safeTapPoint = CGPoint(x: frame.midX, y: (visibleTop + visibleBottom) / 2)
                break
            }
            app.swipeUp(velocity: .fast)
        }

        guard let safeTapPoint else {
            XCTFail("Button never exposed a safe 44-point tap area: \(target)", file: file, line: line)
            return
        }

        let normalizedPoint = CGVector(
            dx: (safeTapPoint.x - appFrame.minX) / appFrame.width,
            dy: (safeTapPoint.y - appFrame.minY) / appFrame.height
        )
        app.coordinate(withNormalizedOffset: normalizedPoint).tap()
    }

    static func canvas(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["score_writing_canvas"]
    }

    static func drawPolyline(
        _ normalizedPoints: [CGVector],
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard normalizedPoints.count > 1 else { return }
        // During the player-card transition two canvases can coexist (the
        // exiting card and the entering one); wait for a single canvas so
        // strokes never land on a view that is about to be removed.
        let canvases = app.descendants(matching: .any).matching(identifier: "score_writing_canvas")
        let settleDeadline = Date().addingTimeInterval(3)
        while canvases.count != 1 && Date() < settleDeadline {
            usleep(100_000)
        }
        let canvas = canvas(in: app)
        guard canvas.waitForExistence(timeout: 5) else {
            XCTFail("score_writing_canvas never appeared", file: file, line: line)
            return
        }
        let keyboardDeadline = Date().addingTimeInterval(3)
        while app.keyboards.firstMatch.exists && Date() < keyboardDeadline {
            usleep(100_000)
        }
        for index in 0..<(normalizedPoints.count - 1) {
            let start = canvas.coordinate(withNormalizedOffset: normalizedPoints[index])
            let end = canvas.coordinate(withNormalizedOffset: normalizedPoints[index + 1])
            start.press(forDuration: 0.05, thenDragTo: end)
        }
    }

    static func drawEllipseZero(
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var points: [CGVector] = []
        let segments = 12
        for index in 0...segments {
            let angle = (Double(index) / Double(segments)) * 2 * Double.pi - Double.pi / 2
            points.append(CGVector(
                dx: 0.5 + 0.20 * cos(angle),
                dy: 0.5 + 0.32 * sin(angle)
            ))
        }
        drawPolyline(points, in: app, file: file, line: line)
    }

    static func drawSeven(
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        drawPolyline([
            CGVector(dx: 0.30, dy: 0.26),
            CGVector(dx: 0.70, dy: 0.26),
        ], in: app, file: file, line: line)
        drawPolyline([
            CGVector(dx: 0.70, dy: 0.26),
            CGVector(dx: 0.44, dy: 0.80),
        ], in: app, file: file, line: line)
    }

    static func drawZigzagScribble(
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        drawPolyline([
            CGVector(dx: 0.14, dy: 0.76),
            CGVector(dx: 0.30, dy: 0.24),
            CGVector(dx: 0.46, dy: 0.76),
            CGVector(dx: 0.62, dy: 0.24),
            CGVector(dx: 0.78, dy: 0.76),
            CGVector(dx: 0.90, dy: 0.30),
        ], in: app, file: file, line: line)
    }

    static func acceptButton(in app: XCUIApplication) -> XCUIElement {
        app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH 'deck_accept_'"))
            .firstMatch
    }

    static func manualUseButton(in app: XCUIApplication) -> XCUIElement {
        app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH 'deck_manual_use_'"))
            .firstMatch
    }

    static func retryButton(in app: XCUIApplication) -> XCUIElement {
        app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH 'deck_retry_'"))
            .firstMatch
    }

    static func rejectionCard(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["deck_invalid_value"]
    }

    static func noInkHint(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["deck_no_ink_hint"]
    }

    static func acceptCurrentConfirmation(
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let accept = acceptButton(in: app)
        guard accept.waitForExistence(timeout: 5) else {
            XCTFail("No confirmation card to accept", file: file, line: line)
            return
        }
        accept.tap()
    }

    static func useManualValue(
        _ value: String,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let field = app.textFields["deck_manual_value"]
        guard field.waitForExistence(timeout: 5) else {
            XCTFail("deck_manual_value text field missing", file: file, line: line)
            return
        }
        field.tap()
        field.press(forDuration: 1)
        if app.menuItems["Select All"].waitForExistence(timeout: 1) {
            app.menuItems["Select All"].tap()
        } else {
            field.tap(withNumberOfTaps: 3, numberOfTouches: 1)
            app.typeText(XCUIKeyboardKey.delete.rawValue)
        }
        app.typeText(value)
        XCTAssertEqual(
            field.value as? String,
            value,
            "Manual score field did not contain the requested value",
            file: file,
            line: line
        )
        let use = manualUseButton(in: app)
        guard use.waitForExistence(timeout: 5) else {
            XCTFail("deck_manual_use button missing", file: file, line: line)
            return
        }
        use.tap()
    }

    /// Draws a zero on the current player's canvas and commits it, handling
    /// every terminal recognition state: confirmation is accepted, a rejection
    /// card falls back to manual entry, and a no-ink hint (touch that failed
    /// to register) redraws and retries once.
    static func commitZeroForCurrentPlayer(
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let recognize = app.buttons["recognize_score_button"]
        let accept = acceptButton(in: app)
        let rejection = rejectionCard(in: app)
        let hint = noInkHint(in: app)

        for _ in 0..<2 {
            drawEllipseZero(in: app, file: file, line: line)
            guard recognize.waitForExistence(timeout: 10) else {
                XCTFail("recognize_score_button missing", file: file, line: line)
                return
            }
            recognize.tap()

            let deadline = Date().addingTimeInterval(20)
            while Date() < deadline {
                if accept.exists || rejection.exists || hint.exists { break }
                usleep(100_000)
            }

            if accept.exists {
                accept.tap()
                return
            }
            if rejection.exists {
                useManualValue("0", in: app, file: file, line: line)
                return
            }
            guard hint.exists else {
                XCTFail("No terminal recognition state appeared", file: file, line: line)
                return
            }
        }
        XCTFail("Failed to commit a zero after redrawing", file: file, line: line)
    }

    static func waitForDeckToClose(
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let deck = app.descendants(matching: .any)["round_entry_deck"]
        let deadline = Date().addingTimeInterval(10)
        while deck.exists && Date() < deadline {
            usleep(100_000)
        }
        XCTAssertFalse(deck.exists, "Score deck did not close", file: file, line: line)
    }

    static func playerPosition(_ position: Int, of total: Int, in app: XCUIApplication) -> XCUIElement {
        app.staticTexts["\(position) / \(total)"]
    }
}

@MainActor
private extension XCTestCase {
    func assertExistsWithDiagnostics(
        _ element: XCUIElement,
        timeout: TimeInterval,
        message: String,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let exists = element.waitForExistence(timeout: timeout)
        if !exists {
            add(XCTAttachment(screenshot: app.screenshot()))
            add(XCTAttachment(string: app.debugDescription))
        }
        XCTAssertTrue(exists, message, file: file, line: line)
    }
}

@MainActor
final class ScoreRecognitionE2ETests: XCTestCase {
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

    func testRecognizeHandwrittenZero() {
        startTwoPlayerGame()
        openScoreDeck()

        ScoreDeckUITestSupport.drawEllipseZero(in: app)
        app.buttons["recognize_score_button"].tap()

        let accept = ScoreDeckUITestSupport.acceptButton(in: app)
        assertExistsWithDiagnostics(
            accept,
            timeout: 20,
            message: "Confirmation card did not appear for handwritten zero",
            in: app
        )
        XCTAssertTrue(app.staticTexts["Is this right?"].exists)
        XCTAssertTrue(app.staticTexts["0"].exists, "Confirmed value was not exactly 0")

        accept.tap()
        XCTAssertTrue(
            ScoreDeckUITestSupport.playerPosition(2, of: 2, in: app).waitForExistence(timeout: 10),
            "Deck did not advance to player 2"
        )
    }

    func testRecognizeHandwrittenSeven() {
        startTwoPlayerGame()
        openScoreDeck()

        ScoreDeckUITestSupport.drawSeven(in: app)
        app.buttons["recognize_score_button"].tap()

        let accept = ScoreDeckUITestSupport.acceptButton(in: app)
        assertExistsWithDiagnostics(
            accept,
            timeout: 20,
            message: "Confirmation card did not appear for handwritten seven",
            in: app
        )
        XCTAssertTrue(app.staticTexts["Is this right?"].exists)
        XCTAssertTrue(app.staticTexts["7"].exists, "Confirmed value was not exactly 7")

        accept.tap()
        XCTAssertTrue(
            ScoreDeckUITestSupport.playerPosition(2, of: 2, in: app).waitForExistence(timeout: 10),
            "Deck did not advance to player 2"
        )
    }

    func testBlankCanvasShowsInlineHintWithNoOverlay() {
        startTwoPlayerGame()
        openScoreDeck()

        app.buttons["recognize_score_button"].tap()

        let hint = ScoreDeckUITestSupport.noInkHint(in: app)
        XCTAssertTrue(hint.waitForExistence(timeout: 15), "Inline no-ink hint did not appear")
        XCTAssertTrue(app.staticTexts["Draw the score first"].exists)

        let reading = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == 'Reading score'"))
        XCTAssertEqual(reading.count, 0, "Reading overlay persisted after the no-ink hint")

        XCTAssertFalse(ScoreDeckUITestSupport.acceptButton(in: app).exists, "Confirmation card appeared without ink")
        XCTAssertFalse(ScoreDeckUITestSupport.rejectionCard(in: app).exists, "Rejection card appeared without ink")
        XCTAssertFalse(app.staticTexts["Is this right?"].exists)
    }

    func testUnreadableShowsManualEntry() {
        startTwoPlayerGame()
        openScoreDeck()

        ScoreDeckUITestSupport.drawZigzagScribble(in: app)
        app.buttons["recognize_score_button"].tap()

        let rejection = ScoreDeckUITestSupport.rejectionCard(in: app)
        XCTAssertTrue(rejection.waitForExistence(timeout: 20), "Rejection card did not appear for scribbled ink")
        XCTAssertTrue(app.staticTexts["Couldn't read that"].exists)

        ScoreDeckUITestSupport.useManualValue("25", in: app)

        XCTAssertTrue(
            ScoreDeckUITestSupport.playerPosition(2, of: 2, in: app).waitForExistence(timeout: 10),
            "Deck did not advance to player 2"
        )

        ScoreDeckUITestSupport.commitZeroForCurrentPlayer(in: app)
        ScoreDeckUITestSupport.waitForDeckToClose(in: app)

        XCTAssertTrue(app.staticTexts["Round 2"].waitForExistence(timeout: 10))
        let committedScore = app.staticTexts["25"]
        assertExistsWithDiagnostics(
            committedScore,
            timeout: 5,
            message: "Committed score 25 is not visible on the scoring screen",
            in: app
        )
    }

    func testRetryKeepsStrokesOnUnreadable() {
        startTwoPlayerGame()
        openScoreDeck()

        ScoreDeckUITestSupport.drawZigzagScribble(in: app)
        app.buttons["recognize_score_button"].tap()

        let rejection = ScoreDeckUITestSupport.rejectionCard(in: app)
        XCTAssertTrue(rejection.waitForExistence(timeout: 20), "Rejection card did not appear for scribbled ink")

        ScoreDeckUITestSupport.retryButton(in: app).tap()

        // A retry re-captures the same strokes. If the canvas had been
        // cleared, the nil capture would surface the no-ink hint instead of
        // the rejection card, so the card returning proves strokes survived.
        XCTAssertTrue(rejection.waitForExistence(timeout: 20), "Rejection card did not re-appear after retry")
        XCTAssertTrue(app.staticTexts["Couldn't read that"].exists)
        XCTAssertFalse(ScoreDeckUITestSupport.noInkHint(in: app).exists, "Retry cleared the canvas ink")
    }

    private func startTwoPlayerGame(first: String = "Alice", second: String = "Bob") {
        let newGame = app.buttons["new_game_button"]
        XCTAssertTrue(newGame.waitForExistence(timeout: 5))
        ScoreDeckUITestSupport.tapButtonInSafeArea(newGame, in: app)

        let tile = app.buttons["game_tile_generic"]
        XCTAssertTrue(tile.waitForExistence(timeout: 5))
        ScoreDeckUITestSupport.tapButtonInSafeArea(tile, in: app)

        let firstField = app.textFields["player_name_field_0"]
        XCTAssertTrue(firstField.waitForExistence(timeout: 5))
        firstField.tap()
        firstField.typeText(first)

        let secondField = app.textFields["player_name_field_1"]
        XCTAssertTrue(secondField.waitForExistence(timeout: 5))
        secondField.tap()
        secondField.typeText(second)

        app.buttons["start_game_button"].tap()
        XCTAssertTrue(app.segmentedControls["win_condition_picker"].waitForExistence(timeout: 5))
        app.buttons["start_game_button"].tap()
        XCTAssertTrue(app.buttons["end_game_button"].waitForExistence(timeout: 5))
    }

    private func openScoreDeck() {
        app.buttons["submit_round_button"].tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["round_entry_deck"].waitForExistence(timeout: 10),
            "Round entry deck did not open"
        )
        ScoreDeckUITestSupport.dismissDeckTutorialIfPresent(in: app)
    }
}
