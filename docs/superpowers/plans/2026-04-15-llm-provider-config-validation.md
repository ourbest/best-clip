# LLM Provider Config Validation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add editable provider/base URL settings for OpenAI, Anthropic, and compatible endpoints, plus a one-tap validation flow that checks whether the saved LLM configuration actually works.

**Architecture:** Keep recommendation generation behind the existing pipeline entry point, but move configuration concerns into settings and a small validation helper. `SettingsStore` will persist provider, base URL, model name, and API key; `SettingsView` will expose those controls and a validation button; `GenerationFlowViewModel` will build the client from the stored configuration and run the validation request. The request path stays generic enough for OpenAI-compatible endpoints, while the existing local fallback remains unchanged when no API key is configured or validation fails.

**Tech Stack:** Swift, SwiftUI, Foundation, XCTest, Keychain-backed local storage.

---

### Task 1: Extend settings storage and defaults for provider + base URL

**Files:**
- Modify: `AutoAlbum/State/SettingsStore.swift`
- Modify: `AutoAlbumTests/SettingsStoreTests.swift`

- [ ] **Step 1: Write the failing test**

Add a test that proves the settings file persists `provider`, `baseURL`, and `modelName`, while the API key stays in Keychain only.

```swift
func testSettingsStorePersistsProviderBaseURLAndModelName() {
    let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("settings.json")
    let secrets = InMemorySecretStore()

    var store = SettingsStore(fileURL: fileURL, secretStore: secrets)
    store.provider = .anthropic
    store.baseURL = "https://api.anthropic.com"
    store.modelName = "claude-sonnet-4"
    store.apiKey = "secret-key"
    store.save()

    let reloaded = SettingsStore(fileURL: fileURL, secretStore: secrets)

    XCTAssertEqual(reloaded.provider, .anthropic)
    XCTAssertEqual(reloaded.baseURL, "https://api.anthropic.com")
    XCTAssertEqual(reloaded.modelName, "claude-sonnet-4")
    XCTAssertEqual(reloaded.apiKey, "secret-key")
    XCTAssertFalse((try? String(contentsOf: fileURL))?.contains("secret-key") == true)
}
```

Add a second test that verifies the defaults:

```swift
func testSettingsStoreProvidesProviderSpecificDefaults() {
    let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("settings-defaults.json")
    let store = SettingsStore(fileURL: fileURL, secretStore: InMemorySecretStore())

    XCTAssertEqual(store.provider, .openAI)
    XCTAssertEqual(store.baseURL, "https://api.openai.com")

    var anthropic = store
    anthropic.provider = .anthropic
    anthropic.applyProviderDefaults()
    XCTAssertEqual(anthropic.baseURL, "https://api.anthropic.com")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
xcodebuild test -scheme AutoAlbum -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:AutoAlbumTests/SettingsStoreTests/testSettingsStorePersistsProviderBaseURLAndModelName -only-testing:AutoAlbumTests/SettingsStoreTests/testSettingsStoreProvidesProviderSpecificDefaults
```

Expected: FAIL because `baseURL` is not yet persisted and provider defaults are not yet available.

- [ ] **Step 3: Write minimal implementation**

Add `baseURL` to `SettingsPayload`, expand `SettingsStore.Provider` to include `.anthropic`, and add a small helper that applies default base URLs when the provider changes:

```swift
mutating func applyProviderDefaults() {
    switch provider {
    case .openAI:
        if baseURL.isEmpty { baseURL = "https://api.openai.com" }
    case .anthropic:
        if baseURL.isEmpty { baseURL = "https://api.anthropic.com" }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run the same `xcodebuild test` command as above.

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add AutoAlbum/State/SettingsStore.swift AutoAlbumTests/SettingsStoreTests.swift
git commit -m "feat: persist llm provider configuration"
```

### Task 2: Expose provider, base URL, and validation controls in Settings UI

**Files:**
- Modify: `AutoAlbum/Views/SettingsView.swift`
- Modify: `AutoAlbum/AppRootView.swift`
- Modify: `AutoAlbum/ViewModels/GenerationFlowViewModel.swift`

- [ ] **Step 1: Write the failing test**

Add a view-model test that proves saving settings updates the provider/base URL and that the validation action surfaces a success or failure state.

```swift
func testViewModelPersistsProviderAndBaseURLBeforeValidation() {
    let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("settings-ui.json")
    let secrets = InMemorySecretStore()
    let store = SettingsStore(fileURL: fileURL, secretStore: secrets)
    let viewModel = GenerationFlowViewModel(settingsStore: store)

    viewModel.settingsProvider = .anthropic
    viewModel.settingsBaseURL = "https://proxy.example.com"
    viewModel.settingsModelName = "claude-sonnet-4"
    viewModel.settingsAPIKey = "sk-test"
    viewModel.saveSettings()

    let reloaded = SettingsStore(fileURL: fileURL, secretStore: secrets)
    XCTAssertEqual(reloaded.provider, .anthropic)
    XCTAssertEqual(reloaded.baseURL, "https://proxy.example.com")
    XCTAssertEqual(reloaded.modelName, "claude-sonnet-4")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
xcodebuild test -scheme AutoAlbum -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:AutoAlbumTests/SettingsStoreTests/testViewModelPersistsProviderAndBaseURLBeforeValidation
```

Expected: FAIL because the view model does not yet track provider/baseURL and the view does not expose a validation action.

- [ ] **Step 3: Write minimal implementation**

Update `SettingsView` so it shows:

- provider picker
- editable base URL field
- existing model name field
- existing API key field
- a new `验证配置` button

Wire the new bindings through `AppRootView` and `GenerationFlowViewModel` so the view can edit `settingsProvider` and `settingsBaseURL`, then save them back into `SettingsStore`.

- [ ] **Step 4: Run test to verify it passes**

Run the same `xcodebuild test` command as above.

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add AutoAlbum/Views/SettingsView.swift AutoAlbum/AppRootView.swift AutoAlbum/ViewModels/GenerationFlowViewModel.swift
git commit -m "feat: expose llm provider settings"
```

### Task 3: Add a one-tap configuration validation path

**Files:**
- Modify: `AutoAlbum/Services/LLMClient.swift`
- Modify: `AutoAlbum/ViewModels/GenerationFlowViewModel.swift`
- Modify: `AutoAlbum/Views/SettingsView.swift`
- Modify: `AutoAlbumTests/LLMClientTests.swift`

- [ ] **Step 1: Write the failing test**

Add a test that proves a valid configuration can be verified without starting a full export, and that invalid configurations report a useful failure.

```swift
func testValidateConfigurationSucceedsWithMockResponse() async throws {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [MockURLProtocol.self]
    let session = URLSession(configuration: configuration)

    MockURLProtocol.requestHandler = { request in
        XCTAssertEqual(request.url?.absoluteString, "https://example.com/v1/chat/completions")
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return response.with(data: Data(#"{"choices":[{"message":{"content":"{\"theme\":\"测试\"}"}}]}"#.utf8))
    }

    let client = LLMClient(
        session: session,
        baseURL: URL(string: "https://example.com")!,
        apiKey: "test-key",
        modelName: "gpt-4o-mini"
    )

    try await client.validateConfiguration()
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
xcodebuild test -scheme AutoAlbum -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:AutoAlbumTests/LLMClientTests/testValidateConfigurationSucceedsWithMockResponse
```

Expected: FAIL because `validateConfiguration()` does not exist yet.

- [ ] **Step 3: Write minimal implementation**

Add a lightweight `validateConfiguration()` method to `LLMClient` that reuses the existing request path but can be called from the settings screen without exporting a video. Use the same request construction as `requestRecommendation(for:)`, but keep the result discardable and return success only when the response decodes correctly.

Expose a `validateConfiguration()` action from `GenerationFlowViewModel` that:

- builds a temporary client from the current settings
- runs the validation call
- updates `saveStatus` with either success or a readable failure message

Update `SettingsView` to call that action from the new validation button and show the current validation state in the UI.

- [ ] **Step 4: Run test to verify it passes**

Run the same `xcodebuild test` command as above.

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add AutoAlbum/Services/LLMClient.swift AutoAlbum/ViewModels/GenerationFlowViewModel.swift AutoAlbum/Views/SettingsView.swift AutoAlbumTests/LLMClientTests.swift
git commit -m "feat: add llm configuration validation"
```

### Task 4: Verify the full flow still falls back safely when configuration is missing or invalid

**Files:**
- Modify: `AutoAlbumTests/MemoryVideoPipelineTests.swift`
- Modify: `AutoAlbumTests/SettingsStoreTests.swift`
- Modify: `AutoAlbum/ViewModels/GenerationFlowViewModel.swift`

- [ ] **Step 1: Write the failing test**

Add a pipeline-level test that proves invalid or missing configuration does not block the local fallback path.

```swift
func testPipelineFallsBackWhenApiKeyIsMissing() async throws {
    let store = SettingsStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("fallback-settings.json"), secretStore: InMemorySecretStore())
    let viewModel = GenerationFlowViewModel(settingsStore: store)

    XCTAssertEqual(viewModel.settingsAPIKey, "")
    await viewModel.generatePreviewExportAsync()
    XCTAssertEqual(viewModel.generationStage, .finished)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
xcodebuild test -scheme AutoAlbum -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:AutoAlbumTests/MemoryVideoPipelineTests/testPipelineFallsBackWhenApiKeyIsMissing
```

Expected: FAIL only if the new validation changes break the current fallback path.

- [ ] **Step 3: Write minimal implementation**

Keep the existing behavior where `MemoryVideoPipeline` returns local recommendations if no API key is configured or if the remote validation fails.

- [ ] **Step 4: Run test to verify it passes**

Run the same `xcodebuild test` command as above.

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add AutoAlbumTests/MemoryVideoPipelineTests.swift AutoAlbumTests/SettingsStoreTests.swift AutoAlbum/ViewModels/GenerationFlowViewModel.swift
git commit -m "test: preserve fallback after llm config validation"
```

### Task 5: Verify the focused suite and git hygiene

**Files:**
- None

- [ ] **Step 1: Run the focused tests**

Run:

```bash
xcodebuild test -scheme AutoAlbum -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:AutoAlbumTests/SettingsStoreTests -only-testing:AutoAlbumTests/LLMClientTests -only-testing:AutoAlbumTests/MemoryVideoPipelineTests
```

Expected: PASS.

- [ ] **Step 2: Run the git hygiene check**

Run:

```bash
git diff --check
```

Expected: no output.

- [ ] **Step 3: Commit any final cleanup**

If the final verification produces a small cleanup diff, make one smallest-possible commit with a message that describes the cleanup accurately.

