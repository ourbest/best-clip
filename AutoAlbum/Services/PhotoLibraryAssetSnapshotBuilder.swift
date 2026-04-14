import AVFoundation
import Photos
import UIKit
import UniformTypeIdentifiers
import Foundation

protocol MediaAssetSnapshotProviding {
    func snapshots(for assets: [PHAsset]) async throws -> [MediaAssetSnapshot]
}

final class PhotoLibraryAssetSnapshotBuilder: MediaAssetSnapshotProviding {
    private let imageManager: PHImageManager
    private let analyzer: MediaAssetAnalyzer

    init(imageManager: PHImageManager = PHImageManager.default(), analyzer: MediaAssetAnalyzer = MediaAssetAnalyzer()) {
        self.imageManager = imageManager
        self.analyzer = analyzer
    }

    func snapshots(for assets: [PHAsset]) async throws -> [MediaAssetSnapshot] {
        try await withThrowingTaskGroup(of: MediaAssetSnapshot.self) { group in
            for asset in assets {
                group.addTask { try await self.snapshot(for: asset) }
            }

            var snapshots: [MediaAssetSnapshot] = []
            for try await snapshot in group {
                snapshots.append(snapshot)
            }

            return snapshots.sorted { $0.timestamp < $1.timestamp }
        }
    }

    func snapshot(for asset: PHAsset) async throws -> MediaAssetSnapshot {
        switch asset.mediaType {
        case .image:
            return try await snapshotForImage(asset)
        case .video:
            return try await snapshotForVideo(asset)
        default:
            return MediaAssetSnapshot(
                id: asset.localIdentifier,
                kind: .photo,
                timestamp: asset.creationDate ?? Date(),
                duration: nil,
                faces: 0,
                scene: "未支持媒体",
                sharpness: 0.5,
                stability: 0.5,
                ocrText: nil,
                speechText: nil,
                sourceURL: nil
            )
        }
    }

    private func snapshotForImage(_ asset: PHAsset) async throws -> MediaAssetSnapshot {
        let payload = try await loadImageData(for: asset)
        let analysis = try analyzer.analyze(imageData: payload.data)
        let sourceURL = try persistImageData(payload.data, asset: asset, suggestedExtension: payload.fileExtension)

        return MediaAssetSnapshot(
            id: asset.localIdentifier,
            kind: .photo,
            timestamp: asset.creationDate ?? Date(),
            duration: nil,
            faces: analysis.faces,
            scene: "照片",
            sharpness: analysis.sharpness,
            stability: min(1.0, 0.65 + analysis.sharpness * 0.3),
            ocrText: analysis.ocrText,
            speechText: nil,
            sourceURL: sourceURL
        )
    }

    private func snapshotForVideo(_ asset: PHAsset) async throws -> MediaAssetSnapshot {
        let avAsset = try await loadVideoAsset(for: asset)
        let sourceURL: URL
        if let url = (avAsset as? AVURLAsset)?.url {
            sourceURL = url
        } else {
            sourceURL = try await persistVideoAsset(avAsset, asset: asset)
        }
        let duration = CMTimeGetSeconds(avAsset.duration)
        let frameImage = try await representativeFrame(from: avAsset)
        let analysis = try analyzer.analyze(image: frameImage)

        return MediaAssetSnapshot(
            id: asset.localIdentifier,
            kind: .video,
            timestamp: asset.creationDate ?? Date(),
            duration: duration.isFinite ? duration : nil,
            faces: analysis.faces,
            scene: "视频",
            sharpness: analysis.sharpness,
            stability: min(1.0, 0.35 + min(max(duration, 0), 30) / 60.0 + analysis.sharpness * 0.15),
            ocrText: analysis.ocrText,
            speechText: nil,
            sourceURL: sourceURL
        )
    }

    private func loadImageData(for asset: PHAsset) async throws -> (data: Data, fileExtension: String) {
        try await withCheckedThrowingContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat
            options.isSynchronous = false

            imageManager.requestImageDataAndOrientation(for: asset, options: options) { data, uti, _, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let data else {
                    continuation.resume(throwing: AnalyzerError.unreadableImage)
                    return
                }

                let fileExtension = uti.flatMap { UTType($0)?.preferredFilenameExtension } ?? "jpg"
                continuation.resume(returning: (data, fileExtension))
            }
        }
    }

    private func loadVideoAsset(for asset: PHAsset) async throws -> AVAsset {
        try await withCheckedThrowingContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true
            options.version = .original

            imageManager.requestAVAsset(forVideo: asset, options: options) { avAsset, _, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let avAsset else {
                    continuation.resume(throwing: MediaSnapshotError.unavailableVideoAsset)
                    return
                }

                continuation.resume(returning: avAsset)
            }
        }
    }

    private func persistImageData(_ data: Data, asset: PHAsset, suggestedExtension: String) throws -> URL {
        let fileURL = temporaryURL(for: asset, extension: suggestedExtension)
        let directoryURL = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    private func persistVideoAsset(_ avAsset: AVAsset, asset: PHAsset) async throws -> URL {
        let outputURL = temporaryURL(for: asset, extension: "mov")
        let directoryURL = outputURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        guard let exportSession = AVAssetExportSession(asset: avAsset, presetName: AVAssetExportPresetPassthrough) else {
            throw MediaSnapshotError.unavailableVideoAsset
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov

        return try await withCheckedThrowingContinuation { continuation in
            exportSession.exportAsynchronously {
                switch exportSession.status {
                case .completed:
                    continuation.resume(returning: outputURL)
                case .failed:
                    continuation.resume(throwing: exportSession.error ?? MediaSnapshotError.unavailableVideoAsset)
                default:
                    continuation.resume(throwing: MediaSnapshotError.unavailableVideoAsset)
                }
            }
        }
    }

    private func representativeFrame(from asset: AVAsset) async throws -> CGImage {
        try await withCheckedThrowingContinuation { continuation in
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 1280, height: 1280)
            let time = CMTime(seconds: 0, preferredTimescale: 600)
            do {
                let image = try generator.copyCGImage(at: time, actualTime: nil)
                continuation.resume(returning: image)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func temporaryURL(for asset: PHAsset, extension fileExtension: String) -> URL {
        let safeIdentifier = asset.localIdentifier.replacingOccurrences(of: "/", with: "_")
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("AutoAlbumSnapshots", isDirectory: true)
            .appendingPathComponent("\(safeIdentifier).\(fileExtension)")
    }
}

enum MediaSnapshotError: Error {
    case unavailableVideoAsset
}
