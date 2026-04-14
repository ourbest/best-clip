import AVFoundation
import XCTest
@testable import AutoAlbum

final class CompositionPlannerTests: XCTestCase {
    func testBuildsPortraitPlanWithOpeningMiddleAndEndingSections() {
        let recommendation = LLMRecommendation(
            theme: "周末日常",
            recommendedStyle: .lifeLog,
            title: "周末碎片",
            subtitle: "把普通的一天，剪成值得回看的回忆",
            highlightItems: [
                .init(id: "photo-1", priority: 1, reason: "适合开头"),
                .init(id: "video-2", priority: 2, reason: "适合作为过渡"),
                .init(id: "photo-3", priority: 3, reason: "适合收尾")
            ],
            musicStyle: "轻快温暖",
            transitionStyle: "柔和",
            sharingCopy: "周末的这些小片段，拼起来就是我喜欢的生活。"
        )

        let assets = [
            MediaAssetSnapshot(
                id: "photo-1",
                kind: .photo,
                timestamp: Date(timeIntervalSince1970: 1_700_200_000),
                duration: nil,
                faces: 2,
                scene: "restaurant",
                sharpness: 0.94,
                stability: 0.88,
                ocrText: nil,
                speechText: nil,
                sourceURL: nil
            ),
            MediaAssetSnapshot(
                id: "video-2",
                kind: .video,
                timestamp: Date(timeIntervalSince1970: 1_700_200_120),
                duration: 12,
                faces: 1,
                scene: "street",
                sharpness: 0.81,
                stability: 0.71,
                ocrText: nil,
                speechText: nil,
                sourceURL: nil
            ),
            MediaAssetSnapshot(
                id: "photo-3",
                kind: .photo,
                timestamp: Date(timeIntervalSince1970: 1_700_200_240),
                duration: nil,
                faces: 3,
                scene: "park",
                sharpness: 0.89,
                stability: 0.91,
                ocrText: nil,
                speechText: nil,
                sourceURL: nil
            )
        ]

        let plan = CompositionPlanner().buildPlan(recommendation: recommendation, assets: assets)

        XCTAssertEqual(plan.aspectRatio, .portrait9x16)
        XCTAssertEqual(plan.sections.first?.assetID, "photo-1")
        XCTAssertEqual(plan.sections.last?.assetID, "photo-3")
        XCTAssertEqual(plan.musicStyle, "轻快温暖")
    }

    func testFallsBackToChronologicalOrderWhenHighlightsDoNotMatch() {
        let recommendation = LLMRecommendation(
            theme: "旅行回顾",
            recommendedStyle: .cinematic,
            title: "旅途",
            subtitle: "沿着时间线回看这次出发",
            highlightItems: [
                .init(id: "missing", priority: 1, reason: "不存在")
            ],
            musicStyle: "氛围感",
            transitionStyle: "柔和",
            sharingCopy: "旅途记录。"
        )

        let earlier = MediaAssetSnapshot(
            id: "photo-1",
            kind: .photo,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            duration: nil,
            faces: 1,
            scene: "station",
            sharpness: 0.9,
            stability: 0.8,
            ocrText: nil,
            speechText: nil,
            sourceURL: nil
        )
        let later = MediaAssetSnapshot(
            id: "video-2",
            kind: .video,
            timestamp: Date(timeIntervalSince1970: 1_700_000_500),
            duration: 8.0,
            faces: 1,
            scene: "airport",
            sharpness: 0.85,
            stability: 0.82,
            ocrText: nil,
            speechText: nil,
            sourceURL: nil
        )

        let plan = CompositionPlanner().buildPlan(recommendation: recommendation, assets: [later, earlier])

        XCTAssertEqual(plan.sections.first?.assetID, "photo-1")
        XCTAssertEqual(plan.sections.last?.assetID, "video-2")
    }

    func testGivesLongerDurationToStableVideoThanShakyVideo() {
        let recommendation = LLMRecommendation(
            theme: "周末日常",
            recommendedStyle: .lifeLog,
            title: "周末碎片",
            subtitle: "把普通的一天，剪成值得回看的回忆",
            highlightItems: [
                .init(id: "stable", priority: 1, reason: "适合承接"),
                .init(id: "shaky", priority: 2, reason: "适合过渡")
            ],
            musicStyle: "轻快温暖",
            transitionStyle: "柔和",
            sharingCopy: "周末的这些小片段，拼起来就是我喜欢的生活。"
        )

        let stable = MediaAssetSnapshot(
            id: "stable",
            kind: .video,
            timestamp: Date(timeIntervalSince1970: 1_700_100_000),
            duration: 8.0,
            faces: 1,
            scene: "park",
            sharpness: 0.88,
            stability: 0.92,
            motion: 0.10,
            ocrText: nil,
            speechText: nil,
            sourceURL: nil
        )
        let shaky = MediaAssetSnapshot(
            id: "shaky",
            kind: .video,
            timestamp: Date(timeIntervalSince1970: 1_700_100_030),
            duration: 8.0,
            faces: 1,
            scene: "street",
            sharpness: 0.88,
            stability: 0.36,
            motion: 0.82,
            ocrText: nil,
            speechText: nil,
            sourceURL: nil
        )

        let plan = CompositionPlanner().buildPlan(recommendation: recommendation, assets: [stable, shaky])

        XCTAssertGreaterThan(plan.sections[0].endSeconds, plan.sections[1].endSeconds)
    }

    func testSplitsLongHighMotionVideoIntoMultipleSections() {
        let recommendation = LLMRecommendation(
            theme: "旅行回顾",
            recommendedStyle: .cinematic,
            title: "旅途",
            subtitle: "沿着时间线回看这次出发",
            highlightItems: [
                .init(id: "video-fast", priority: 1, reason: "适合拆成快节奏镜头")
            ],
            musicStyle: "氛围感",
            transitionStyle: "柔和",
            sharingCopy: "旅途记录。"
        )

        let video = MediaAssetSnapshot(
            id: "video-fast",
            kind: .video,
            timestamp: Date(timeIntervalSince1970: 1_700_300_000),
            duration: 18.0,
            faces: 0,
            scene: "city",
            sharpness: 0.72,
            stability: 0.31,
            motion: 0.82,
            ocrText: nil,
            speechText: nil,
            sourceURL: nil
        )

        let plan = CompositionPlanner().buildPlan(recommendation: recommendation, assets: [video])

        let sections = plan.sections.filter { $0.assetID == "video-fast" }

        XCTAssertEqual(sections.count, 3)
        XCTAssertLessThanOrEqual(sections[0].endSeconds, sections[1].startSeconds)
        XCTAssertLessThanOrEqual(sections[1].endSeconds, sections[2].startSeconds)
        XCTAssertGreaterThan(sections[0].endSeconds - sections[0].startSeconds, 0)
    }

    func testKeepsContentRichVideoLongerThanMotionOnlyVideo() {
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

        let contentSections = plan.sections.filter { $0.assetID == "content" }
        let motionSections = plan.sections.filter { $0.assetID == "motion" }

        XCTAssertEqual(contentSections.count, 1)
        XCTAssertGreaterThan(contentSections[0].endSeconds - contentSections[0].startSeconds, motionSections[0].endSeconds - motionSections[0].startSeconds)
    }

    func testVideoComposerUsesSectionSourceRange() {
        let composer = VideoComposer()
        let range = composer.clipTimeRange(
            for: CompositionSection(assetID: "video", startSeconds: 4.0, endSeconds: 9.0),
            sourceDuration: CMTime(seconds: 10.0, preferredTimescale: 600)
        )

        XCTAssertEqual(CMTimeGetSeconds(range.start), 4.0, accuracy: 0.0001)
        XCTAssertEqual(CMTimeGetSeconds(range.duration), 5.0, accuracy: 0.0001)
    }

    func testVideoSegmentScorerPrefersSingleSectionForContentRichVideos() {
        let scorer = VideoSegmentScorer()
        let asset = MediaAssetSnapshot(
            id: "content-rich",
            kind: .video,
            timestamp: Date(timeIntervalSince1970: 1_700_500_000),
            duration: 11.0,
            faces: 3,
            scene: "restaurant",
            sharpness: 0.9,
            stability: 0.86,
            motion: 0.18,
            ocrText: "happy birthday",
            speechText: "cheers",
            sourceURL: nil
        )

        let sections = scorer.sections(for: asset, isLast: false)

        XCTAssertEqual(sections.count, 1)
        XCTAssertGreaterThan(sections[0].endSeconds - sections[0].startSeconds, 2.2)
    }

    func testVideoSegmentScorerSplitsMotionHeavyVideos() {
        let scorer = VideoSegmentScorer()
        let asset = MediaAssetSnapshot(
            id: "motion-heavy",
            kind: .video,
            timestamp: Date(timeIntervalSince1970: 1_700_500_030),
            duration: 18.0,
            faces: 0,
            scene: "city",
            sharpness: 0.7,
            stability: 0.25,
            motion: 0.88,
            ocrText: nil,
            speechText: nil,
            sourceURL: nil
        )

        let sections = scorer.sections(for: asset, isLast: false)

        XCTAssertEqual(sections.count, 3)
        XCTAssertLessThan(sections[0].endSeconds - sections[0].startSeconds, 4.5)
    }

    func testMotionPolicyPrefersFewerSegmentsForContentRichVideos() {
        let policy = MotionSegmentPolicy()
        let contentRich = MediaAssetSnapshot(
            id: "content-rich",
            kind: .video,
            timestamp: Date(timeIntervalSince1970: 1_700_600_000),
            duration: 14.0,
            faces: 3,
            scene: "restaurant",
            sharpness: 0.9,
            stability: 0.86,
            motion: 0.18,
            ocrText: "happy birthday",
            speechText: "cheers",
            sourceURL: nil
        )
        let motionOnly = MediaAssetSnapshot(
            id: "motion-only",
            kind: .video,
            timestamp: Date(timeIntervalSince1970: 1_700_600_030),
            duration: 14.0,
            faces: 0,
            scene: "street",
            sharpness: 0.7,
            stability: 0.34,
            motion: 0.82,
            ocrText: nil,
            speechText: nil,
            sourceURL: nil
        )

        XCTAssertLessThanOrEqual(
            policy.segmentCount(for: contentRich, sourceDuration: 14.0, contentScore: ContentSegmentPolicy().contentScore(for: contentRich)),
            policy.segmentCount(for: motionOnly, sourceDuration: 14.0, contentScore: ContentSegmentPolicy().contentScore(for: motionOnly))
        )
    }

    func testContentPolicyIncreasesDurationForTextAndFaces() {
        let policy = ContentSegmentPolicy()
        let rich = MediaAssetSnapshot(
            id: "rich",
            kind: .video,
            timestamp: Date(timeIntervalSince1970: 1_700_600_060),
            duration: 10.0,
            faces: 3,
            scene: "dinner",
            sharpness: 0.9,
            stability: 0.88,
            motion: 0.16,
            ocrText: "happy birthday",
            speechText: "cheers",
            sourceURL: nil
        )
        let sparse = MediaAssetSnapshot(
            id: "sparse",
            kind: .video,
            timestamp: Date(timeIntervalSince1970: 1_700_600_090),
            duration: 10.0,
            faces: 0,
            scene: "street",
            sharpness: 0.9,
            stability: 0.88,
            motion: 0.16,
            ocrText: nil,
            speechText: nil,
            sourceURL: nil
        )

        XCTAssertGreaterThan(policy.contentScore(for: rich), policy.contentScore(for: sparse))
        XCTAssertGreaterThan(policy.minimumSegmentDuration(for: rich), policy.minimumSegmentDuration(for: sparse))
    }
}
