import XCTest

@MainActor
final class LegalSupportAndReviewUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-in-memory-store", "-force-light-theme"]
        app.launch()

        if app.buttons["onboarding_skip_button"].waitForExistence(timeout: 1) {
            app.buttons["onboarding_skip_button"].tap()
        }

        XCTAssertTrue(app.buttons["new_game_button"].waitForExistence(timeout: 3))
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    func testLegalSupportLinksAreReachable() throws {
        let moreTab = app.buttons["tab_more"]
        XCTAssertTrue(moreTab.waitForExistence(timeout: 3))
        moreTab.tap()

        XCTAssertTrue(app.navigationBars["Legal & Support"].waitForExistence(timeout: 3))

        let privacyLink = app.descendants(matching: .any)["privacy_policy_link"]
        let supportLink = app.descendants(matching: .any)["support_link"]
        XCTAssertTrue(privacyLink.waitForExistence(timeout: 2))
        XCTAssertTrue(supportLink.waitForExistence(timeout: 2))
        XCTAssertEqual(privacyLink.label, "PipCount Privacy Policy")
        XCTAssertEqual(supportLink.label, "PipCount Support")
    }

    func testHomeAlwaysOffersPipCountUpgradeWhenLocked() throws {
        let upgradeButton = app.buttons["home_upgrade_button"]
        XCTAssertTrue(upgradeButton.waitForExistence(timeout: 3))
        XCTAssertEqual(upgradeButton.label, "Upgrade to PipCount Pro")
    }

    func testEligibleReviewUsesNativeRequestWithoutCustomSheet() throws {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = ["-in-memory-store", "-force-light-theme", "-force-review-ask"]
        app.launch()

        if app.buttons["onboarding_skip_button"].waitForExistence(timeout: 1) {
            app.buttons["onboarding_skip_button"].tap()
        }
        XCTAssertTrue(app.buttons["new_game_button"].waitForExistence(timeout: 3))

        app.buttons["new_game_button"].tap()
        chooseGame("game_tile_generic")
        fillPlayerNames(["Ada", "Ben"])
        app.buttons["start_game_button"].tap()
        XCTAssertTrue(app.segmentedControls["win_condition_picker"].waitForExistence(timeout: 2))
        app.buttons["start_game_button"].tap()
        XCTAssertTrue(app.buttons["end_game_button"].waitForExistence(timeout: 3))

        app.buttons["submit_round_button"].tap()
        app.buttons["end_game_button"].tap()
        app.alerts.buttons["End Game"].tap()

        XCTAssertTrue(app.staticTexts["winner_text"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["review_ask_rate_button"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["review_ask_later_button"].exists)
        XCTAssertFalse(app.staticTexts["How was game night?"].exists)
    }


    private func chooseGame(_ tileID: String) {
        XCTAssertTrue(app.buttons[tileID].waitForExistence(timeout: 2))
        app.buttons[tileID].tap()
        let continueButton = app.buttons["game_picker_continue_button"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 2))
        continueButton.tap()
    }

    private func fillPlayerNames(_ names: [String]) {
        for (index, name) in names.enumerated() {
            let field = app.textFields["player_name_field_\(index)"]
            XCTAssertTrue(field.waitForExistence(timeout: 2))
            field.tap()
            field.typeText(name)
        }
    }
}
