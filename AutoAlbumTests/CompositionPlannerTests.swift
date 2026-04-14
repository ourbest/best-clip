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
}
