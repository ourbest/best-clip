import XCTest

final class GenerationFlowUITests: XCTestCase {
    func testUserCanGenerateAStubbedMemoryVideoEndToEnd() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting",
            "-stubRecommendation",
            "生活记录感"
        ]
        app.launch()

        app.buttons["new_memory_video"].tap()
        app.buttons["asset_asset-1"].tap()
        app.buttons["continue_to_style"].tap()
        app.buttons["generate_video"].tap()

        XCTAssertTrue(app.staticTexts["generation_complete"].waitForExistence(timeout: 30))
    }
}
