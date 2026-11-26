import XCTest

final class NavigationTests: XCTestCase {
    @MainActor
    func testPhoneTabsShowTheirDestinations() {
        let app = isolatedApp()
        app.launch()

        let tabs = app.tabBars.buttons
        let destinations = [
            ("Today", "Your first workout"),
            ("Train", "No templates"),
            ("Coach", "New chat"),
            ("Log", "No completed workouts"),
            ("Progress", "No progress data")
        ]
        XCTAssertTrue(tabs["Today"].waitForExistence(timeout: 5))
        XCTAssertEqual(tabs.allElementsBoundByIndex.map(\.label), destinations.map { $0.0 })
        for (tab, content) in destinations {
            tabs[tab].tap()
            XCTAssertTrue(app.descendants(matching: .any)[content].firstMatch.waitForExistence(timeout: 5),
                          "Missing content for \(tab)")
        }

        tabs["Train"].tap()
        app.buttons["Calendar"].tap()
        XCTAssertTrue(app.navigationBars["Calendar"].waitForExistence(timeout: 5))
        app.buttons["Go to Today"].tap()
        XCTAssertTrue(app.staticTexts["Your first workout"].waitForExistence(timeout: 5))
        XCTAssertTrue(tabs["Today"].isSelected)
        app.buttons["Watch status"].tap()
        XCTAssertTrue(app.alerts["Watch status unavailable"].waitForExistence(timeout: 5))
        app.alerts["Watch status unavailable"].buttons["OK"].tap()
        app.buttons["today.profile"].tap()
        XCTAssertTrue(app.staticTexts["Workout data stays on your devices"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testCoachReopensWeeklyReport() {
        let app = isolatedApp()
        app.launch()
        app.tabBars.buttons["Coach"].tap()
        app.buttons["New chat"].tap()
        app.buttons["Show my weekly report"].tap()
        XCTAssertTrue(app.staticTexts["You"].waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        app.tabBars.buttons["Coach"].tap()
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "coach.chat.")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["You"].waitForExistence(timeout: 5))
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
    func testPlannedWorkoutSurvivesRelaunch() {
        let app = isolatedApp()
        launchTemplates(in: app)
        app.buttons["templates.empty.add"].tap()
        app.textFields["template.name"].tap()
        app.textFields["template.name"].typeText("Full Body A")
        app.buttons["template.exercise.add"].tap()
        app.buttons["Shoulder Press"].tap()
        app.buttons["Save"].tap()

        app.tabBars.buttons["Today"].tap()
        let planButton = app.buttons["Plan a Workout"]
        XCTAssertTrue(planButton.waitForExistence(timeout: 5))
        planButton.tap()
        app.buttons["Full Body A"].tap()
        XCTAssertTrue(app.staticTexts["Shoulder Press"].waitForExistence(timeout: 5))

        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["Full Body A"].waitForExistence(timeout: 5))

        app.tabBars.buttons["Train"].tap()
        let viewWorkout = app.buttons["View Workout"]
        XCTAssertTrue(viewWorkout.waitForExistence(timeout: 5))
        viewWorkout.tap()
        XCTAssertTrue(app.staticTexts["Shoulder Press"].waitForExistence(timeout: 5))
        let start = app.buttons["today.workout"]
        if !start.isHittable { app.swipeUp() }
        start.tap()
        XCTAssertTrue(app.staticTexts["Scheduled workout"].waitForExistence(timeout: 5))
        app.buttons["Full Body A"].tap()
        XCTAssertTrue(app.staticTexts["In progress"].waitForExistence(timeout: 5))
        app.buttons["Close"].tap()
        start.tap()
        XCTAssertTrue(app.staticTexts["In progress"].waitForExistence(timeout: 5))
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
    func testBlankWorkoutAppearsInLogAndWeeklyProgressAfterRelaunch() {
        let app = isolatedApp()
        app.launch()
        app.buttons["today.profile"].tap()
        app.buttons["profile.walkthrough"].tap()
        XCTAssertTrue(app.staticTexts["First workout"].waitForExistence(timeout: 5))
        let start = app.buttons["today.workout"]
        for _ in 0..<3 where !start.isHittable { app.swipeUp() }
        start.tap()
        let blank = app.buttons["Start Blank Workout"]
        XCTAssertTrue(blank.waitForExistence(timeout: 8))
        blank.tap()
        XCTAssertTrue(app.staticTexts["Choose an exercise, then log a set with the reps you completed."].waitForExistence(timeout: 5))
        app.buttons["Add Exercise"].tap()
        app.buttons["Squat"].tap()
        app.buttons["Log Set"].tap()
        let reps = app.textFields["Reps"]
        XCTAssertTrue(reps.waitForExistence(timeout: 5))
        reps.tap()
        reps.typeText("8")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Set 1: 8 reps"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["When you’re done, finish the workout to save it to Training Log."].waitForExistence(timeout: 5))
        let finish = app.buttons["Finish Workout"]
        if !finish.isHittable || finish.frame.midY > app.frame.maxY - 50 { app.swipeUp() }
        finish.tap()
        XCTAssertTrue(app.staticTexts["Tap Log to find your saved workout."].waitForExistence(timeout: 5))
        app.buttons["Close"].tap()

        app.terminate()
        app.launch()
        app.tabBars.buttons["Log"].tap()
        XCTAssertTrue(app.staticTexts["Squat"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["8 reps"].exists)
        app.tabBars.buttons["Today"].tap()
        XCTAssertTrue(app.buttons["today.profile"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Tap Log to find your saved workout."].exists)
        app.tabBars.buttons["Progress"].tap()
        XCTAssertTrue(app.staticTexts["1 workout · 1 confirmed set"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testWelcomeResumesDraftAndSavesRecurringSplit() {
        let app = isolatedApp(skipWelcome: false)
        app.launch()
        XCTAssertTrue(app.buttons["welcome.build"].waitForExistence(timeout: 8))
        app.buttons["welcome.build"].tap()
        let preview = app.buttons["setup.preview"]
        if !preview.isHittable { app.swipeUp() }
        preview.tap()
        XCTAssertTrue(app.navigationBars["Your weekly split"].waitForExistence(timeout: 5))
        app.buttons.matching(identifier: "setup.editRoutine").firstMatch.tap()
        let name = app.textFields["template.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        let oldName = name.value as? String ?? ""
        name.typeText("X")
        let newName = name.value as? String ?? ""
        XCTAssertNotEqual(newName, oldName)
        let editedRoutine = app.buttons.matching(NSPredicate(format: "label == %@", "Edit " + newName)).firstMatch
        app.buttons["Save"].tap()
        XCTAssertTrue(editedRoutine.waitForExistence(timeout: 5))

        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["welcome.build"].waitForExistence(timeout: 8))
        app.buttons["welcome.build"].tap()
        XCTAssertTrue(editedRoutine.waitForExistence(timeout: 5))
        let save = app.buttons["setup.save"]
        for _ in 0..<4 where !save.isHittable { app.swipeUp() }
        save.tap()
        XCTAssertTrue(app.alerts["First workout"].waitForExistence(timeout: 5))
        app.alerts["First workout"].buttons["Maybe later"].tap()
        app.buttons["today.profile"].tap()
        XCTAssertTrue(app.buttons["profile.trainingSetup"].waitForExistence(timeout: 5))
        app.buttons["profile.trainingSetup"].tap()
        XCTAssertTrue(editedRoutine.waitForExistence(timeout: 5))
    }

    @MainActor
    private func replaceText(in field: XCUIElement, old: String, new: String) {
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count) + new)
    }

    @MainActor
    private func isolatedApp(skipWelcome: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["RAYDIUN_UI_TEST_STORE"] = UUID().uuidString
        if skipWelcome { app.launchArguments.append("-RaydiunSkipWelcome") }
        return app
    }

    @MainActor
    private func launchTemplates(in app: XCUIApplication) {
        app.launch()
        app.tabBars.buttons["Train"].tap()
    }
}
