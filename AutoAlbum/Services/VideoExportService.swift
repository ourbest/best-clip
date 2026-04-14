import AVFoundation
import Foundation

final class VideoExportService {
    enum ExportError: Error {
        case missingExportSession
        case exportFailed
    }

    func export(plan: CompositionPlan, assets: [MediaAssetSnapshot], to destinationURL: URL) throws -> URL {
        let composer = VideoComposer()
        let composition = composer.makeComposition(plan: plan, assets: assets)
        try removeIfNeeded(destinationURL)

        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw ExportError.missingExportSession
        }

        exportSession.outputURL = destinationURL
        exportSession.outputFileType = .mov
        exportSession.shouldOptimizeForNetworkUse = true
        exportSession.exportAsynchronously {}

        return destinationURL
    }

    private func removeIfNeeded(_ url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}
