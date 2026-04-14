import XCTest
@testable import AutoAlbum

final class AppStateTests: XCTestCase {
    func testInitialStateStartsOnHomeAndHasNoPendingJob() {
        let state = AppState()

        XCTAssertEqual(state.currentRoute, .home)
        XCTAssertFalse(state.isGenerating)
        XCTAssertNil(state.latestError)
    }
}
