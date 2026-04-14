import AVFoundation
import Foundation

protocol VideoExporting {
    func export(plan: CompositionPlan, assets: [MediaAssetSnapshot], to destinationURL: URL) async throws -> URL
}

final class VideoExportService: VideoExporting {
    enum ExportError: Error {
        case missingExportSession
        case exportFailed
    }

    func export(plan: CompositionPlan, assets: [MediaAssetSnapshot], to destinationURL: URL) async throws -> URL {
        let composer = VideoComposer()
        let composition = composer.makeComposition(plan: plan, assets: assets)
        try removeIfNeeded(destinationURL)

        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw ExportError.missingExportSession
        }

        exportSession.outputURL = destinationURL
        exportSession.outputFileType = .mov
        exportSession.shouldOptimizeForNetworkUse = true

        return try await withCheckedThrowingContinuation { continuation in
            exportSession.exportAsynchronously {
                switch exportSession.status {
                case .completed:
                    continuation.resume(returning: destinationURL)
                case .failed:
                    continuation.resume(throwing: exportSession.error ?? ExportError.exportFailed)
                case .cancelled:
                    continuation.resume(throwing: ExportError.exportFailed)
                default:
                    continuation.resume(throwing: ExportError.exportFailed)
                }
            }
        }
    }

    private func removeIfNeeded(_ url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}
