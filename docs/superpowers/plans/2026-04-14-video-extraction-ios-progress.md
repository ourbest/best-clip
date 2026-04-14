# Video Extraction iOS Progress Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Align the iOS video extraction pipeline with the documented Python selection flow by making video analysis, cut selection, scoring, and fallback behavior explicit, testable, and incremental.

**Architecture:** Keep the current mobile pipeline split into small services, but make the video path follow the documented order: extract candidate segments first, score and filter them second, and let `CompositionPlanner` only assemble the final plan. Video analysis remains the source of motion and content signals, while the segment policies decide how many sections to emit and how long each section should be. High-level recommendation and title generation stay in the upper pipeline layers and do not get mixed into cut selection.

**Tech Stack:** Swift, XCTest, AVFoundation, Photos, UIKit.

---

### Task 1: Lock the documented cut-selection behavior with tests

**Files:**
- Modify: `AutoAlbumTests/CompositionPlannerTests.swift`
- Modify: `AutoAlbumTests/MemoryVideoPipelineTests.swift`

- [ ] **Step 1: Write the failing test**

Add a test that proves a content-rich video with strong faces/text/speech keeps one section, while a motion-heavy video of the same duration is split into multiple sections. Add a second test that proves a very short video always stays as one section even if motion is high.

```swift
func testContentRichVideoStaysSingleSectionWhileHighMotionVideoSplits() {
    let recommendation = LLMRecommendation(
        theme: "周末日常",
        recommendedStyle: .lifeLog,
        title: "周末碎片",
        subtitle: "把普通的一天，剪成值得回看的回忆",
        highlightItems: [
            .init(id: "content", priority: 1, reason: "有人物和语音"),
            .init(id: "motion", priority: 2, reason: "纯动作镜头")
        ],
        musicStyle: "轻快温暖",
        transitionStyle: "柔和",
        sharingCopy: "周末的这些小片段，拼起来就是我喜欢的生活。"
    )

    let contentRich = MediaAssetSnapshot(
        id: "content",
        kind: .video,
        timestamp: Date(timeIntervalSince1970: 1_700_400_000),
        duration: 12.0,
        faces: 3,
        scene: "restaurant",
        sharpness: 0.84,
        stability: 0.86,
        motion: 0.14,
        ocrText: "happy birthday",
        speechText: "cheers",
        sourceURL: nil
    )

    let motionOnly = MediaAssetSnapshot(
        id: "motion",
        kind: .video,
        timestamp: Date(timeIntervalSince1970: 1_700_400_030),
        duration: 12.0,
        faces: 0,
        scene: "street",
        sharpness: 0.84,
        stability: 0.42,
        motion: 0.82,
        ocrText: nil,
        speechText: nil,
        sourceURL: nil
    )

    let plan = CompositionPlanner().buildPlan(recommendation: recommendation, assets: [contentRich, motionOnly])

    XCTAssertEqual(plan.sections.filter { $0.assetID == "content" }.count, 1)
    XCTAssertGreaterThan(plan.sections.filter { $0.assetID == "motion" }.count, 1)
}
```

```swift
func testShortHighMotionVideoNeverSplits() {
    let recommendation = LLMRecommendation(
        theme: "旅行回顾",
        recommendedStyle: .cinematic,
        title: "旅途",
        subtitle: "沿着时间线回看这次出发",
        highlightItems: [
            .init(id: "short", priority: 1, reason: "短视频")
        ],
        musicStyle: "氛围感",
        transitionStyle: "柔和",
        sharingCopy: "旅途记录。"
    )

    let shortVideo = MediaAssetSnapshot(
        id: "short",
        kind: .video,
        timestamp: Date(timeIntervalSince1970: 1_700_500_000),
        duration: 5.0,
        faces: 0,
        scene: "street",
        sharpness: 0.7,
        stability: 0.25,
        motion: 0.88,
        ocrText: nil,
        speechText: nil,
        sourceURL: nil
    )

    let plan = CompositionPlanner().buildPlan(recommendation: recommendation, assets: [shortVideo])

    XCTAssertEqual(plan.sections.filter { $0.assetID == "short" }.count, 1)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme AutoAlbum -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:AutoAlbumTests/CompositionPlannerTests/testContentRichVideoStaysSingleSectionWhileHighMotionVideoSplits -only-testing:AutoAlbumTests/CompositionPlannerTests/testShortHighMotionVideoNeverSplits`

Expected: FAIL because the current plan logic does not yet guarantee this exact separation.

- [ ] **Step 3: Write minimal implementation**

No implementation in this task.

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme AutoAlbum -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:AutoAlbumTests/CompositionPlannerTests/testContentRichVideoStaysSingleSectionWhileHighMotionVideoSplits -only-testing:AutoAlbumTests/CompositionPlannerTests/testShortHighMotionVideoNeverSplits`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add AutoAlbumTests/CompositionPlannerTests.swift
git commit -m "test: lock video cut selection behavior"
```

### Task 2: Make the segment scorer explicitly match the documented rules

**Files:**
- Modify: `AutoAlbum/Services/MotionSegmentPolicy.swift`
- Modify: `AutoAlbum/Services/ContentSegmentPolicy.swift`
- Modify: `AutoAlbum/Services/VideoSegmentScorer.swift`
- Modify: `AutoAlbumTests/CompositionPlannerTests.swift`

- [ ] **Step 1: Write the failing test**

Add a focused test for the scorer itself that proves:
- videos shorter than 6 seconds stay as one section
- strong content at or above the content threshold keeps 12-second clips as a single section
- motion-heavy long videos can expand to 2 or 3 sections

```swift
func testVideoSegmentScorerAppliesDocumentedThresholds() {
    let scorer = VideoSegmentScorer()
    let shortVideo = MediaAssetSnapshot(
        id: "short",
        kind: .video,
        timestamp: Date(),
        duration: 5.5,
        faces: 0,
        scene: "street",
        sharpness: 0.7,
        stability: 0.2,
        motion: 0.9,
        ocrText: nil,
        speechText: nil,
        sourceURL: nil
    )

    let contentRich = MediaAssetSnapshot(
        id: "content",
        kind: .video,
        timestamp: Date(),
        duration: 12.0,
        faces: 3,
        scene: "restaurant",
        sharpness: 0.9,
        stability: 0.9,
        motion: 0.1,
        ocrText: "menu",
        speechText: "welcome",
        sourceURL: nil
    )

    XCTAssertEqual(scorer.sections(for: shortVideo, isLast: false).count, 1)
    XCTAssertEqual(scorer.sections(for: contentRich, isLast: false).count, 1)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme AutoAlbum -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:AutoAlbumTests/CompositionPlannerTests/testVideoSegmentScorerAppliesDocumentedThresholds`

Expected: FAIL if current policy thresholds or segment counts are out of sync with the document.

- [ ] **Step 3: Write minimal implementation**

Adjust only the policy thresholds and scorer math needed to make the tests pass. Keep these rules explicit:
- short videos below 6 seconds never split
- content score at or above 0.5 suppresses splitting for clips up to 12 seconds
- 16-second high-motion videos can become 3 sections
- 10-second medium-motion videos can become 2 sections

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme AutoAlbum -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:AutoAlbumTests/CompositionPlannerTests/testVideoSegmentScorerAppliesDocumentedThresholds`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add AutoAlbum/Services/MotionSegmentPolicy.swift AutoAlbum/Services/ContentSegmentPolicy.swift AutoAlbum/Services/VideoSegmentScorer.swift AutoAlbumTests/CompositionPlannerTests.swift
git commit -m "refactor: align video segment scoring with docs"
```

### Task 3: Keep `CompositionPlanner` as orchestration only

**Files:**
- Modify: `AutoAlbum/Services/CompositionPlanner.swift`
- Modify: `AutoAlbumTests/CompositionPlannerTests.swift`

- [ ] **Step 1: Write the failing test**

Add a test that proves `CompositionPlanner` preserves highlighted asset order when highlights match, and falls back to chronological ordering without re-sorting video sections internally.

```swift
func testCompositionPlannerOnlyOrchestratesSectionOrdering() {
    let recommendation = LLMRecommendation(
        theme: "旅行回顾",
        recommendedStyle: .cinematic,
        title: "旅途",
        subtitle: "沿着时间线回看这次出发",
        highlightItems: [
            .init(id: "photo-1", priority: 1, reason: "开头"),
            .init(id: "video-2", priority: 2, reason: "过渡")
        ],
        musicStyle: "氛围感",
        transitionStyle: "柔和",
        sharingCopy: "旅途记录。"
    )

    let plan = CompositionPlanner().buildPlan(
        recommendation: recommendation,
        assets: [
            MediaAssetSnapshot(
                id: "video-2",
                kind: .video,
                timestamp: Date(timeIntervalSince1970: 1_700_000_100),
                duration: 10.0,
                faces: 1,
                scene: "airport",
                sharpness: 0.85,
                stability: 0.8,
                motion: 0.2,
                ocrText: nil,
                speechText: nil,
                sourceURL: nil
            ),
            MediaAssetSnapshot(
                id: "photo-1",
                kind: .photo,
                timestamp: Date(timeIntervalSince1970: 1_700_000_000),
                duration: nil,
                faces: 2,
                scene: "station",
                sharpness: 0.9,
                stability: 0.8,
                ocrText: nil,
                speechText: nil,
                sourceURL: nil
            )
        ]
    )

    XCTAssertEqual(plan.sections.first?.assetID, "photo-1")
    XCTAssertEqual(plan.sections.last?.assetID, "video-2")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme AutoAlbum -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:AutoAlbumTests/CompositionPlannerTests/testCompositionPlannerOnlyOrchestratesSectionOrdering`

Expected: FAIL if `CompositionPlanner` is still doing anything more than orchestration.

- [ ] **Step 3: Write minimal implementation**

Keep `CompositionPlanner` responsible only for:
- ordering assets by highlight list or timestamp fallback
- mapping photos to fixed durations
- delegating all video slicing to `VideoSegmentScorer`

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme AutoAlbum -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:AutoAlbumTests/CompositionPlannerTests/testCompositionPlannerOnlyOrchestratesSectionOrdering`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add AutoAlbum/Services/CompositionPlanner.swift AutoAlbumTests/CompositionPlannerTests.swift
git commit -m "refactor: keep composition planner orchestration-only"
```

### Task 4: Update the pipeline entry points and add coverage for the end-to-end path

**Files:**
- Modify: `AutoAlbum/Services/MemoryVideoPipeline.swift`
- Modify: `AutoAlbum/ViewModels/GenerationFlowViewModel.swift`
- Modify: `AutoAlbumTests/MemoryVideoPipelineTests.swift`

- [ ] **Step 1: Write the failing test**

Add an end-to-end test that imports mixed assets, builds a summary, requests a recommendation, builds a plan, and exports with the current video cut behavior preserved in the final plan.

```swift
func testEndToEndPipelinePreservesVideoCutRules() async throws {
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
        ),
        MediaAssetSnapshot(
            id: "video-2",
            kind: .video,
            timestamp: Date(timeIntervalSince1970: 1_700_000_120),
            duration: 18.0,
            faces: 0,
            scene: "street",
            sharpness: 0.7,
            stability: 0.3,
            motion: 0.85,
            ocrText: nil,
            speechText: nil
        )
    ]

    let pipeline = MemoryVideoPipeline(
        recommendationClient: FakeRecommendationClient(),
        exportService: FakeExportService()
    )

    let result = try await pipeline.generate(from: assets, to: FileManager.default.temporaryDirectory.appendingPathComponent("cut-rules.mov"))

    XCTAssertGreaterThan(result.plan.sections.filter { $0.assetID == "video-2" }.count, 1)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme AutoAlbum -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:AutoAlbumTests/MemoryVideoPipelineTests/testEndToEndPipelinePreservesVideoCutRules`

Expected: FAIL until the pipeline path is wired to the current cut-selection logic.

- [ ] **Step 3: Write minimal implementation**

Make sure the pipeline uses `AssetSummaryBuilder` for selection input and `CompositionPlanner` for plan creation without bypassing the video cut scorer.

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme AutoAlbum -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:AutoAlbumTests/MemoryVideoPipelineTests/testEndToEndPipelinePreservesVideoCutRules`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add AutoAlbum/Services/MemoryVideoPipeline.swift AutoAlbum/ViewModels/GenerationFlowViewModel.swift AutoAlbumTests/MemoryVideoPipelineTests.swift
git commit -m "feat: preserve documented video cut flow end to end"
```

### Task 5: Verify the full mobile repo remains green

**Files:**
- None

- [ ] **Step 1: Run the focused test suite**

Run: `xcodebuild test -scheme AutoAlbum -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:AutoAlbumTests/CompositionPlannerTests -only-testing:AutoAlbumTests/MemoryVideoPipelineTests`

Expected: PASS.

- [ ] **Step 2: Run the git hygiene check**

Run: `git diff --check`

Expected: no output.

- [ ] **Step 3: Commit any final cleanup**

If the final verification uncovers a small cleanup, make one last commit with the smallest possible diff and a message that describes the cleanup accurately.
