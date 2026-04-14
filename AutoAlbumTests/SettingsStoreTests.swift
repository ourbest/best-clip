import XCTest
@testable import AutoAlbum

final class SettingsStoreTests: XCTestCase {
    func testLoadsDefaultProviderAndPersistsTheAPIKey() {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("settings.json")
        let store = SettingsStore(fileURL: fileURL)

        XCTAssertEqual(store.provider, .openAI)
        XCTAssertEqual(store.modelName, "gpt-4o-mini")

        var updated = store
        updated.apiKey = "test-key"
        updated.save()

        let reloaded = SettingsStore(fileURL: fileURL)
        XCTAssertEqual(reloaded.apiKey, "test-key")
    }
}
