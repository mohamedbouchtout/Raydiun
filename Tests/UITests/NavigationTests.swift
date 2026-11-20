import XCTest

final class NavigationTests: XCTestCase {
    @MainActor
    func testPhoneTabsShowTheirDestinations() {
        let app = XCUIApplication()
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
}
