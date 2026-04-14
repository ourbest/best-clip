import AVFoundation
import CoreGraphics
import Foundation
import PhotosUI
import UIKit
import UniformTypeIdentifiers

protocol MediaSelectionItem {
    func loadFileURL() async throws -> URL?
    func loadData() async throws -> Data?
}

protocol MediaSelectionImporting {
    func importSnapshots(from items: [any MediaSelectionItem]) async throws -> [MediaAssetSnapshot]
}

final class PhotosPickerAssetImporter: MediaSelectionImporting {
    private let analyzer: MediaAssetAnalyzer
    private let videoAnalyzer: VideoAnalyzing

    init(
        analyzer: MediaAssetAnalyzer = MediaAssetAnalyzer(),
        videoAnalyzer: VideoAnalyzing? = nil
    ) {
        self.analyzer = analyzer
        self.videoAnalyzer = videoAnalyzer ?? VideoAssetAnalyzer(imageAnalyzer: analyzer)
    }

    func importSnapshots(from items: [any MediaSelectionItem]) async throws -> [MediaAssetSnapshot] {
        try await withThrowingTaskGroup(of: MediaAssetSnapshot.self) { group in
            for item in items {
                group.addTask { try await self.snapshot(for: item) }
            }

            var snapshots: [MediaAssetSnapshot] = []
            for try await snapshot in group {
                snapshots.append(snapshot)
            }

            return snapshots.sorted { $0.timestamp < $1.timestamp }
        }
    }

    private func snapshot(for item: any MediaSelectionItem) async throws -> MediaAssetSnapshot {
        if let fileURL = try await item.loadFileURL() {
            return try await snapshot(from: fileURL)
        }

        if let data = try await item.loadData() {
            return try await snapshot(from: data)
        }

        throw ImportError.unreadableItem
    }

    private func snapshot(from data: Data) async throws -> MediaAssetSnapshot {
        // Detect if data is video by checking magic bytes (ftyp = MP4/MOV)
        if isVideoData(data) {
            return try await snapshotForVideoData(data)
        }

        let analysis = try analyzer.analyze(imageData: data)
        let fileURL = persist(data: data, suggestedExtension: "jpg")
        let previewURL = persistPreviewImage(from: data, namePrefix: "photo")

        return MediaAssetSnapshot(
            id: UUID().uuidString,
            kind: .photo,
            timestamp: Date(),
            duration: nil,
            faces: analysis.faces,
            scene: "照片",
            sharpness: analysis.sharpness,
            stability: min(1.0, 0.65 + analysis.sharpness * 0.3),
            ocrText: analysis.ocrText,
            speechText: nil,
            sourceURL: fileURL,
            previewURL: previewURL
        )
    }

    private func isVideoData(_ data: Data) -> Bool {
        guard data.count >= 12 else { return false }
        // Check for 'ftyp' at offset 4 (MP4/MOV format)
        let bytes = [UInt8](data.prefix(12))
        return bytes[4] == 0x66 && bytes[5] == 0x74 && bytes[6] == 0x79 && bytes[7] == 0x70
    }

    private func snapshotForVideoData(_ data: Data) async throws -> MediaAssetSnapshot {
        let tempURL = persist(data: data, suggestedExtension: "mov")
        let asset = AVURLAsset(url: tempURL)
        let analysis = try await videoAnalyzer.analyze(video: asset)
        let frameImage = try await representativeFrame(from: asset)
        let persistedURL = persistVideo(at: tempURL)
        let previewURL = persistPreviewImage(from: frameImage, namePrefix: "video")
        let duration = CMTimeGetSeconds(try await asset.load(.duration))

        return MediaAssetSnapshot(
            id: UUID().uuidString,
            kind: .video,
            timestamp: Date(),
            duration: duration.isFinite ? duration : nil,
            faces: analysis.faces,
            scene: "视频",
            sharpness: analysis.sharpness,
            stability: analysis.stability,
            ocrText: analysis.ocrText,
            speechText: nil,
            sourceURL: persistedURL,
            previewURL: previewURL
        )
    }

    private func snapshot(from fileURL: URL) async throws -> MediaAssetSnapshot {
        let fileType = UTType(filenameExtension: fileURL.pathExtension)
        if fileType?.conforms(to: .movie) == true || fileType?.conforms(to: .video) == true {
            return try await snapshotForVideo(fileURL: fileURL)
        }

        let data = try Data(contentsOf: fileURL)
        let analysis = try analyzer.analyze(imageData: data)
        let persistedURL = persist(data: data, suggestedExtension: fileURL.pathExtension.isEmpty ? "jpg" : fileURL.pathExtension)
        let previewURL = persistPreviewImage(from: data, namePrefix: "photo")

        return MediaAssetSnapshot(
            id: UUID().uuidString,
            kind: .photo,
            timestamp: Date(),
            duration: nil,
            faces: analysis.faces,
            scene: "照片",
            sharpness: analysis.sharpness,
            stability: min(1.0, 0.65 + analysis.sharpness * 0.3),
            ocrText: analysis.ocrText,
            speechText: nil,
            sourceURL: persistedURL,
            previewURL: previewURL
        )
    }

    private func snapshotForVideo(fileURL: URL) async throws -> MediaAssetSnapshot {
        let asset = AVURLAsset(url: fileURL)
        let analysis = try await videoAnalyzer.analyze(video: asset)
        let frameImage = try await representativeFrame(from: asset)
        let persistedURL = persistVideo(at: fileURL)
        let previewURL = persistPreviewImage(from: frameImage, namePrefix: "video")
        let duration = CMTimeGetSeconds(try await asset.load(.duration))

        return MediaAssetSnapshot(
            id: UUID().uuidString,
            kind: .video,
            timestamp: Date(),
            duration: duration.isFinite ? duration : nil,
            faces: analysis.faces,
            scene: "视频",
            sharpness: analysis.sharpness,
            stability: analysis.stability,
            ocrText: analysis.ocrText,
            speechText: nil,
            sourceURL: persistedURL,
            previewURL: previewURL
        )
    }

    private func persistPreviewImage(from data: Data, namePrefix: String) -> URL? {
        guard let image = UIImage(data: data) else { return nil }
        if let cgImage = image.cgImage ?? image.scaledCGImage(maxDimension: 640) {
            return persistPreviewImage(from: cgImage, namePrefix: namePrefix)
        }

        return nil
    }

    private func persistPreviewImage(from image: CGImage, namePrefix: String) -> URL? {
        let thumbnail = UIImage(cgImage: image)
        let targetSize = thumbnail.thumbnailSize(maxDimension: 640)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let rendered = renderer.image { _ in
            thumbnail.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        guard let data = rendered.jpegData(compressionQuality: 0.86) else {
            return nil
        }

        return persist(data: data, suggestedExtension: "jpg", namePrefix: namePrefix)
    }

    private func representativeFrame(from asset: AVAsset) async throws -> CGImage {
        try await withCheckedThrowingContinuation { continuation in
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 1280, height: 1280)
            do {
                let image = try generator.copyCGImage(at: CMTime(seconds: 0, preferredTimescale: 600), actualTime: nil)
                continuation.resume(returning: image)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func persist(data: Data, suggestedExtension: String, namePrefix: String = "asset") -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("AutoAlbumImports", isDirectory: true)
            .appendingPathComponent("\(namePrefix)-\(UUID().uuidString).\(suggestedExtension)")
        let directoryURL = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
        try? data.write(to: url, options: .atomic)
        return url
    }

    private func persistVideo(at sourceURL: URL) -> URL {
        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AutoAlbumImports", isDirectory: true)
            .appendingPathComponent("video-\(UUID().uuidString).\(sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension)")
        let directoryURL = destinationURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
        try? FileManager.default.removeItem(at: destinationURL)
        try? FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        return destinationURL
    }
}

private extension UIImage {
    func thumbnailSize(maxDimension: CGFloat) -> CGSize {
        let longestSide = max(size.width, size.height)
        guard longestSide > maxDimension, longestSide > 0 else {
            return size
        }

        let scale = maxDimension / longestSide
        return CGSize(width: size.width * scale, height: size.height * scale)
    }

    func scaledCGImage(maxDimension: CGFloat) -> CGImage? {
        let targetSize = thumbnailSize(maxDimension: maxDimension)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let rendered = renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return rendered.cgImage
    }
}

enum ImportError: LocalizedError {
    case unreadableItem

    var errorDescription: String? {
        switch self {
        case .unreadableItem:
            return "无法读取所选素材"
        }
    }
}
