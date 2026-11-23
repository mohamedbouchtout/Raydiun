import XCTest

final class NavigationTests: XCTestCase {
    @MainActor
    func testPhoneTabsShowTheirDestinations() {
        let app = isolatedApp()
        app.launch()

        for (tab, content) in [
            ("Today", "No active workout"),
            ("Templates", "No templates"),
            ("History", "No workout history"),
            ("Progress", "No progress data"),
            ("Settings", "Workout data stays on your devices")
        ] {
            app.tabBars.buttons[tab].tap()
            XCTAssertTrue(app.staticTexts[content].exists, "Missing content for \(tab)")
        }
    }

    @MainActor
    func testTemplateCRUDPersistsAcrossRelaunch() {
        let app = isolatedApp()
        launchTemplates(in: app)
        XCTAssertTrue(app.staticTexts["No templates"].waitForExistence(timeout: 5))

        app.buttons["templates.empty.add"].tap()
        XCTAssertFalse(app.buttons["Save"].isEnabled)
        app.textFields["template.name"].tap()
        app.textFields["template.name"].typeText("Push Day")
        app.buttons["template.exercise.add"].tap()
        app.buttons["Shoulder Press"].tap()
        app.buttons["Save"].tap()

        app.terminate()
        launchTemplates(in: app)
        let original = app.staticTexts["Push Day"]
        XCTAssertTrue(original.waitForExistence(timeout: 5))
        original.tap()
        XCTAssertTrue(app.staticTexts["Shoulder Press"].exists)
        app.textFields["template.name"].tap()
        app.textFields["template.name"].typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "Push Day".count) + "Upper Body")
        app.buttons["Save"].tap()

        app.terminate()
        launchTemplates(in: app)
        let updated = app.staticTexts["Upper Body"]
        XCTAssertTrue(updated.waitForExistence(timeout: 5))
        updated.swipeLeft()
        app.buttons["Delete"].tap()
        app.buttons["Delete Template"].tap()

        app.terminate()
        launchTemplates(in: app)
        XCTAssertTrue(app.staticTexts["No templates"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testCancelDiscardsNewTemplate() {
        let app = isolatedApp()
        launchTemplates(in: app)
        let add = app.buttons["templates.empty.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        app.textFields["template.name"].tap()
        app.textFields["template.name"].typeText("Discard this draft")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["No templates"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func isolatedApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["RAYDIUN_UI_TEST_STORE"] = UUID().uuidString
        return app
    }

    @MainActor
    private func launchTemplates(in app: XCUIApplication) {
        app.launch()
        app.tabBars.buttons["Templates"].tap()
    }
}
