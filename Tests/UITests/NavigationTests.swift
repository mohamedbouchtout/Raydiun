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
    func testCustomExerciseValidationAndRenameUpdateSavedTemplate() {
        let app = isolatedApp()
        launchTemplates(in: app)
        app.buttons["exercise.library"].tap()
        app.buttons["exercise.library.add"].tap()

        let name = app.textFields["exercise.custom.name"]
        let save = app.buttons["exercise.custom.save"]
        let validation = app.staticTexts["exercise.custom.validation"]
        save.tap()
        XCTAssertEqual(validation.label, "Enter an exercise name.")
        name.tap()
        name.typeText(" squat ")
        save.tap()
        XCTAssertEqual(validation.label, "An exercise with this name already exists.")

        replaceText(in: name, old: " squat ", new: "Step Up")
        save.tap()
        app.buttons["Done"].tap()
        app.buttons["templates.empty.add"].tap()
        app.textFields["template.name"].tap()
        app.textFields["template.name"].typeText("Leg Day")
        app.buttons["template.exercise.add"].tap()
        app.buttons["Step Up"].tap()
        app.buttons["Save"].tap()

        app.terminate()
        launchTemplates(in: app)
        app.buttons["exercise.library"].tap()
        let custom = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Step Up")).firstMatch
        XCTAssertTrue(custom.waitForExistence(timeout: 5))
        custom.tap()
        replaceText(in: name, old: "Step Up", new: "STEP UP")
        save.tap()
        XCTAssertTrue(app.navigationBars["Exercise Library"].exists)

        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "STEP UP")).firstMatch.tap()
        replaceText(in: name, old: "STEP UP", new: "Box Step Up")
        save.tap()
        app.buttons["Done"].tap()

        app.terminate()
        launchTemplates(in: app)
        app.staticTexts["Leg Day"].tap()
        XCTAssertTrue(app.staticTexts["Box Step Up"].exists)
    }

    @MainActor
    private func replaceText(in field: XCUIElement, old: String, new: String) {
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count) + new)
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
