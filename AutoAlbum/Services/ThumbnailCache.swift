import Foundation
import ImageIO
import UIKit

protocol ThumbnailCaching {
    func thumbnailData(for previewURL: URL, maxDimension: CGFloat) async -> Data?
}

final class ThumbnailCache: ThumbnailCaching {
    static let shared = ThumbnailCache()

    private let memoryCache = NSCache<NSString, NSData>()
    private let generator: (URL, CGFloat) async -> Data?

    init(generator: @escaping (URL, CGFloat) async -> Data? = ThumbnailCache.makeThumbnailData(for:maxDimension:)) {
        self.generator = generator
        memoryCache.countLimit = 96
    }

    func thumbnailData(for previewURL: URL, maxDimension: CGFloat) async -> Data? {
        let cacheKey = cacheKey(for: previewURL, maxDimension: maxDimension)

        if let cached = memoryCache.object(forKey: cacheKey) as Data? {
            return cached
        }

        let data = await generator(previewURL, maxDimension)
        guard let data else { return nil }

        memoryCache.setObject(data as NSData, forKey: cacheKey)
        return data
    }

    private func cacheKey(for previewURL: URL, maxDimension: CGFloat) -> NSString {
        "\(previewURL.path)-\(Int(maxDimension))" as NSString
    }

    private static func makeThumbnailData(for previewURL: URL, maxDimension: CGFloat) async -> Data? {
        await Task.detached(priority: .utility) {
            guard let source = CGImageSourceCreateWithURL(previewURL as CFURL, nil) else { return nil }

            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: Int(maxDimension),
                kCGImageSourceShouldCacheImmediately: false
            ]

            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                return try? Data(contentsOf: previewURL)
            }

            let image = UIImage(cgImage: cgImage)
            return image.jpegData(compressionQuality: 0.86)
        }.value
    }
}
