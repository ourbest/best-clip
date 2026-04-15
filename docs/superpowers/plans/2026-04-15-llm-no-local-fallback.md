# LLM Failure Handling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Surface LLM request failures in the generation flow instead of silently falling back to a local recommendation.

**Architecture:** Remove the remote-failure fallback from `MemoryVideoPipeline`, then teach `GenerationFlowViewModel` and the generation UI to carry and display a visible error state. Keep the existing missing-API-key fallback path unchanged for now. Add tests that lock the new failure behavior and preserve the no-key fallback behavior.

**Tech Stack:** Swift, SwiftUI, Foundation, XCTest.

---

### Task 1: Make remote recommendation failures throw

**Files:**
- Modify: `AutoAlbum/Services/MemoryVideoPipeline.swift`
- Modify: `AutoAlbumTests/MemoryVideoPipelineTests.swift`

- [ ] **Step 1: Write the failing test**

Add a test that proves a failing recommendation client causes `generate(from:to:)` to throw instead of returning a fallback recommendation.

```swift
func testRemoteRecommendationFailureThrows() async throws {
    let assets = [
        MediaAssetSnapshot(
            id: "photo-1",
            kind: .photo,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            duration: nil,
            faces: 2,
            scene: "restaurant",
            sharpness: 0.95,
            stability: 0.9,
            ocrText: "happy birthday",
            speechText: nil
        )
    ]

    let pipeline = MemoryVideoPipeline(
        recommendationClient: FailingRecommendationClient()
    )

    do {
        _ = try await pipeline.generate(
            from: assets,
            to: FileManager.default.temporaryDirectory.appendingPathComponent("remote-failure.mov")
        )
        XCTFail("Expected pipeline to throw")
    } catch {
        XCTAssertTrue(error.localizedDescription.isEmpty == false)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
xcodebuild test -scheme AutoAlbum -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:AutoAlbumTests/MemoryVideoPipelineTests/testRemoteRecommendationFailureThrows
```

Expected: FAIL because the pipeline currently falls back locally.

- [ ] **Step 3: Write minimal implementation**

Remove the `catch { return fallbackRecommendation(...) }` path from `loadRecommendation(for:)` and let the recommendation client error propagate.

- [ ] **Step 4: Run test to verify it passes**

Run the same `xcodebuild test` command as above.

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add AutoAlbum/Services/MemoryVideoPipeline.swift AutoAlbumTests/MemoryVideoPipelineTests.swift
git commit -m "feat: surface llm failures instead of local fallback"
```

### Task 2: Surface generation failures in the view model and UI

**Files:**
- Modify: `AutoAlbum/ViewModels/GenerationFlowViewModel.swift`
- Modify: `AutoAlbum/AppRootView.swift`
- Modify: `AutoAlbum/Views/GenerationProgressView.swift`
- Modify: `AutoAlbum/Views/SettingsView.swift`
- Modify: `AutoAlbumTests/LLMClientTests.swift`

- [ ] **Step 1: Write the failing test**

Add a view model test that proves a remote recommendation failure sets a visible generation error state.

```swift
func testGeneratePreviewExportShowsGenerationErrorWhenRecommendationFails() async {
    let store = SettingsStore(
        fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("failure-settings.json"),
        secretStore: InMemorySecretStore()
    )
    var configured = store
    configured.apiKey = "test-key"
    configured.baseURL = "https://example.com"
    configured.modelName = "gpt-4o-mini"

    let viewModel = GenerationFlowViewModel(
        settingsStore: configured,
        pipeline: MemoryVideoPipeline(recommendationClient: FailingRecommendationClient())
    )

    await viewModel.generatePreviewExportAsync()

    XCTAssertEqual(viewModel.generationStage, .failed)
    XCTAssertTrue(viewModel.generationErrorMessage?.contains("失败") == true)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
xcodebuild test -scheme AutoAlbum -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:AutoAlbumTests/LLMClientTests/testGeneratePreviewExportShowsGenerationErrorWhenRecommendationFails
```

Expected: FAIL until the view model exposes a failure state.

- [ ] **Step 3: Write minimal implementation**

Add a `.failed` generation stage, store an error message in the view model, and keep the generation screen on error instead of navigating to the result screen. Add a clear action that lets the user jump to Settings from the failure state.

- [ ] **Step 4: Run test to verify it passes**

Run the same `xcodebuild test` command as above.

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add AutoAlbum/ViewModels/GenerationFlowViewModel.swift AutoAlbum/AppRootView.swift AutoAlbum/Views/GenerationProgressView.swift AutoAlbum/Views/SettingsView.swift AutoAlbumTests/LLMClientTests.swift
git commit -m "feat: surface generation failures in ui"
```

### Task 3: Verify the existing no-key fallback still works

**Files:**
- Modify: `AutoAlbumTests/MemoryVideoPipelineTests.swift`

- [ ] **Step 1: Keep or add the no-key fallback test**

Make sure the current test that proves generation still works without an API key remains in place.

- [ ] **Step 2: Run the focused fallback test**

Run:

```bash
xcodebuild test -scheme AutoAlbum -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:AutoAlbumTests/MemoryVideoPipelineTests/testFallsBackToLocalRecommendationWhenClientFails
```

Expected: PASS.

- [ ] **Step 3: Commit any small cleanup**

If the failure-state UI needs a tiny cleanup after tests pass, make a final small commit with the minimal diff.

