import XCTest
@testable import AutoAlbum

final class AssetSummaryBuilderTests: XCTestCase {
    func testRanksStablePhotoBeforeShakyVideo() {
        let assets = [
            MediaAssetSnapshot(
                id: "photo-1",
                kind: .photo,
                timestamp: Date(timeIntervalSince1970: 1_700_000_000),
                duration: nil,
                faces: 2,
                scene: "restaurant",
                sharpness: 0.94,
                stability: 0.88,
                ocrText: "happy birthday",
                speechText: nil
            ),
            MediaAssetSnapshot(
                id: "video-2",
                kind: .video,
                timestamp: Date(timeIntervalSince1970: 1_700_000_030),
                duration: 12.4,
                faces: 1,
                scene: "street",
                sharpness: 0.41,
                stability: 0.29,
                ocrText: nil,
                speechText: "let's go"
            )
        ]

        let summary = AssetSummaryBuilder().build(from: assets)

        XCTAssertEqual(summary.highlightItems.first?.id, "photo-1")
        XCTAssertEqual(summary.recommendedTheme, "周末日常")
    }
}
