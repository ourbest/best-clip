import XCTest
@testable import AutoAlbum

final class ProjectHistoryStoreTests: XCTestCase {
    func testPersistsAndReloadsRecentProjects() {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("history.json")
        let store = ProjectHistoryStore(fileURL: fileURL)

        store.save([
            .init(id: "1", title: "周末碎片", updatedAt: Date(timeIntervalSince1970: 1_700_000_000))
        ])

        let reloaded = ProjectHistoryStore(fileURL: fileURL)
        XCTAssertEqual(reloaded.load().first?.title, "周末碎片")
    }
}
