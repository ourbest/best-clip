import Foundation
import Photos

final class VideoPhotoLibrarySaver {
    enum SaveError: LocalizedError {
        case unavailable

        var errorDescription: String? {
            switch self {
            case .unavailable:
                return "无法保存视频到相册"
            }
        }
    }

    func saveVideo(at url: URL) async throws {
        try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .video, fileURL: url, options: nil)
            }, completionHandler: { success, error in
                if success {
                    continuation.resume(returning: ())
                    return
                }

                continuation.resume(throwing: error ?? SaveError.unavailable)
            })
        }
    }
}
