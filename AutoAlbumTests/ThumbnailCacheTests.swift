import XCTest
import UIKit
@testable import AutoAlbum

final class ThumbnailCacheTests: XCTestCase {
    func testCachesThumbnailDataForRepeatedRequests() async throws {
        let previewURL = try makePreviewImageURL()
        var invocationCount = 0
        let cache = ThumbnailCache(generator: { url, _ in
            invocationCount += 1
            return try? Data(contentsOf: url)
        })

        let first = await cache.thumbnailData(for: previewURL, maxDimension: 160)
        let second = await cache.thumbnailData(for: previewURL, maxDimension: 160)

        XCTAssertNotNil(first)
        XCTAssertEqual(first, second)
        XCTAssertEqual(invocationCount, 1)
    }

    func testUsesSeparateCacheEntriesForDifferentSizes() async throws {
        let previewURL = try makePreviewImageURL()
        var invocationCount = 0
        let cache = ThumbnailCache(generator: { url, _ in
            invocationCount += 1
            return try? Data(contentsOf: url)
        })

        _ = await cache.thumbnailData(for: previewURL, maxDimension: 160)
        _ = await cache.thumbnailData(for: previewURL, maxDimension: 320)

        XCTAssertEqual(invocationCount, 2)
    }
}

private func makePreviewImageURL() throws -> URL {
    let image = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32)).image { context in
        UIColor.systemTeal.setFill()
        context.fill(CGRect(origin: .zero, size: CGSize(width: 32, height: 32)))
        UIColor.white.setFill()
        context.fill(CGRect(x: 8, y: 8, width: 16, height: 16))
    }

    let url = FileManager.default.temporaryDirectory.appendingPathComponent("thumbnail-cache-test.jpg")
    try? FileManager.default.removeItem(at: url)

    guard let data = image.jpegData(compressionQuality: 0.9) else {
        throw NSError(domain: "AutoAlbumTests", code: -1)
    }

    try data.write(to: url, options: .atomic)
    return url
}
