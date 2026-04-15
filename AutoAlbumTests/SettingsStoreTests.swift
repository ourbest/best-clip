import XCTest
@testable import AutoAlbum

final class SettingsStoreTests: XCTestCase {
    func testLoadsDefaultProviderAndPersistsTheAPIKey() {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("settings.json")
        let secrets = InMemorySecretStore()
        let store = SettingsStore(fileURL: fileURL, secretStore: secrets)

        XCTAssertEqual(store.provider, .openAI)
        XCTAssertEqual(store.modelName, "gpt-4o-mini")
        XCTAssertEqual(store.baseURL, "https://api.openai.com")

        var updated = store
        updated.provider = .anthropic
        updated.baseURL = "https://api.anthropic.com"
        updated.modelName = "claude-sonnet-4"
        updated.apiKey = "test-key"
        updated.save()

        let reloaded = SettingsStore(fileURL: fileURL, secretStore: secrets)
        XCTAssertEqual(reloaded.provider, .anthropic)
        XCTAssertEqual(reloaded.baseURL, "https://api.anthropic.com")
        XCTAssertEqual(reloaded.modelName, "claude-sonnet-4")
        XCTAssertEqual(reloaded.apiKey, "test-key")
        XCTAssertEqual(secrets.string(for: "autoalbum.settings.apiKey.\(fileURL.path)"), "test-key")

        let rawSettingsData = try? Data(contentsOf: fileURL)
        let rawSettingsText = rawSettingsData.flatMap { String(data: $0, encoding: .utf8) }
        XCTAssertFalse(rawSettingsText?.contains("test-key") == true)
    }

    func testProviderDefaultsCanBeAppliedManually() {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("settings-defaults.json")
        let store = SettingsStore(fileURL: fileURL, secretStore: InMemorySecretStore())

        var anthropic = store
        anthropic.provider = .anthropic
        anthropic.baseURL = ""
        anthropic.applyProviderDefaults()
        XCTAssertEqual(anthropic.baseURL, "https://api.anthropic.com")

        var openAI = store
        openAI.provider = .openAI
        openAI.baseURL = ""
        openAI.applyProviderDefaults()
        XCTAssertEqual(openAI.baseURL, "https://api.openai.com")
    }

    func testViewModelCanPersistEditedSettings() {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("settings-view-model.json")
        let secrets = InMemorySecretStore()
        let store = SettingsStore(fileURL: fileURL, secretStore: secrets)
        let viewModel = GenerationFlowViewModel(settingsStore: store)

        viewModel.settingsProvider = .anthropic
        viewModel.settingsBaseURL = "https://proxy.example.com"
        viewModel.settingsModelName = "gpt-4.1-mini"
        viewModel.settingsAPIKey = "edited-key"
        viewModel.saveSettings()

        let reloaded = SettingsStore(fileURL: fileURL, secretStore: secrets)
        XCTAssertEqual(reloaded.provider, .anthropic)
        XCTAssertEqual(reloaded.baseURL, "https://proxy.example.com")
        XCTAssertEqual(reloaded.modelName, "gpt-4.1-mini")
        XCTAssertEqual(reloaded.apiKey, "edited-key")
    }

    func testValidateSettingsRejectsMissingAPIKey() async {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("settings-validation.json")
        let store = SettingsStore(fileURL: fileURL, secretStore: InMemorySecretStore())
        let viewModel = GenerationFlowViewModel(settingsStore: store)

        await viewModel.validateSettings()

        XCTAssertEqual(viewModel.validationStatus, "请先填写 API Key")
    }
}
