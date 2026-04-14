import XCTest
@testable import AutoAlbum

final class SettingsStoreTests: XCTestCase {
    func testLoadsDefaultProviderAndPersistsTheAPIKey() {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("settings.json")
        let secrets = InMemorySecretStore()
        let store = SettingsStore(fileURL: fileURL, secretStore: secrets)

        XCTAssertEqual(store.provider, .openAI)
        XCTAssertEqual(store.modelName, "gpt-4o-mini")

        var updated = store
        updated.apiKey = "test-key"
        updated.save()

        let reloaded = SettingsStore(fileURL: fileURL, secretStore: secrets)
        XCTAssertEqual(reloaded.apiKey, "test-key")
        XCTAssertEqual(secrets.string(for: "autoalbum.settings.apiKey.\(fileURL.path)"), "test-key")

        let rawSettingsData = try? Data(contentsOf: fileURL)
        let rawSettingsText = rawSettingsData.flatMap { String(data: $0, encoding: .utf8) }
        XCTAssertFalse(rawSettingsText?.contains("test-key") == true)
    }

    func testViewModelCanPersistEditedSettings() {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("settings-view-model.json")
        let secrets = InMemorySecretStore()
        let store = SettingsStore(fileURL: fileURL, secretStore: secrets)
        let viewModel = GenerationFlowViewModel(settingsStore: store)

        viewModel.settingsModelName = "gpt-4.1-mini"
        viewModel.settingsAPIKey = "edited-key"
        viewModel.saveSettings()

        let reloaded = SettingsStore(fileURL: fileURL, secretStore: secrets)
        XCTAssertEqual(reloaded.modelName, "gpt-4.1-mini")
        XCTAssertEqual(reloaded.apiKey, "edited-key")
    }
}
