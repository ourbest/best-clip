import AVFoundation
import CoreGraphics
import Foundation
import UIKit

protocol ImageAnalyzing {
    func analyze(image: CGImage) throws -> MediaAssetObservation
}

extension MediaAssetAnalyzer: ImageAnalyzing {}

struct VideoAssetObservation {
    let faces: Int
    let ocrText: String?
    let sharpness: Double
    let stability: Double
    let motion: Double
    let sampledFrameCount: Int
}

protocol VideoAnalyzing {
    func analyze(video asset: AVAsset) async throws -> VideoAssetObservation
    func analyze(frames: [CGImage], duration: Double) throws -> VideoAssetObservation
}

protocol VideoFrameSampling {
    func sampleFrames(from asset: AVAsset, times: [CMTime]) async throws -> [CGImage]
}

final class AVAssetFrameSampler: VideoFrameSampling {
    func sampleFrames(from asset: AVAsset, times: [CMTime]) async throws -> [CGImage] {
        var frames: [CGImage] = []

        for time in times {
            if let frame = try await sampleFrame(from: asset, at: time) {
                frames.append(frame)
            }
        }

        return frames
    }

    private func sampleFrame(from asset: AVAsset, at time: CMTime) async throws -> CGImage? {
        try await withCheckedThrowingContinuation { continuation in
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 1280, height: 1280)
            generator.requestedTimeToleranceBefore = .zero
            generator.requestedTimeToleranceAfter = .zero

            do {
                let image = try generator.copyCGImage(at: time, actualTime: nil)
                continuation.resume(returning: image)
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }
}

final class VideoAssetAnalyzer: VideoAnalyzing {
    private let imageAnalyzer: ImageAnalyzing
    private let frameSampler: VideoFrameSampling

    init(
        imageAnalyzer: ImageAnalyzing = MediaAssetAnalyzer(),
        frameSampler: VideoFrameSampling = AVAssetFrameSampler()
    ) {
        self.imageAnalyzer = imageAnalyzer
        self.frameSampler = frameSampler
    }

    func analyze(video asset: AVAsset) async throws -> VideoAssetObservation {
        let duration = CMTimeGetSeconds(try await asset.load(.duration))
        return try await analyze(video: asset, duration: duration)
    }

    func analyze(video asset: AVAsset, duration: Double) async throws -> VideoAssetObservation {
        let frames = try await frameSampler.sampleFrames(from: asset, times: sampleTimes(for: duration))
        return try analyze(frames: frames, duration: duration)
    }

    func analyze(frames: [CGImage], duration: Double) throws -> VideoAssetObservation {
        guard !frames.isEmpty else {
            throw VideoAnalysisError.noFrames
        }

        let observations = try frames.map { try imageAnalyzer.analyze(image: $0) }
        let faces = observations.map(\.faces).max() ?? 0
        let sharpness = observations.map(\.sharpness).reduce(0, +) / Double(observations.count)
        let ocrText = combineTexts(observations.compactMap(\.ocrText))
        let motion = averageMotion(in: frames)
        let durationFactor = duration.isFinite ? min(max(duration, 0) / 24.0, 1.0) : 0.0
        let contentStability = 1.0 - min(max(motion, 0.0), 1.0)
        let stability = min(max(contentStability * 0.75 + durationFactor * 0.25, 0.0), 1.0)

        return VideoAssetObservation(
            faces: faces,
            ocrText: ocrText,
            sharpness: sharpness,
            stability: stability,
            motion: motion,
            sampledFrameCount: frames.count
        )
    }

    private func sampleTimes(for duration: Double) -> [CMTime] {
        guard duration.isFinite, duration > 0 else {
            return [CMTime(seconds: 0, preferredTimescale: 600)]
        }

        let points: [Double] = [0.08, 0.28, 0.5, 0.72, 0.92]
        return points.map { CMTime(seconds: max(duration * $0, 0.0), preferredTimescale: 600) }
    }

    private func averageMotion(in frames: [CGImage]) -> Double {
        guard frames.count > 1 else { return 0.0 }

        let differences = zip(frames, frames.dropFirst()).map { frameDifference(between: $0.0, and: $0.1) }
        return differences.reduce(0, +) / Double(differences.count)
    }

    private func combineTexts(_ texts: [String]) -> String? {
        let uniqueTexts = texts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .reduce(into: [String]()) { result, text in
                if !result.contains(text) {
                    result.append(text)
                }
            }

        guard !uniqueTexts.isEmpty else { return nil }

        return uniqueTexts.prefix(3).joined(separator: "\n")
    }

    private func frameDifference(between lhs: CGImage, and rhs: CGImage) -> Double {
        guard let lhsPixels = sampledGrayPixels(from: lhs), let rhsPixels = sampledGrayPixels(from: rhs), lhsPixels.count == rhsPixels.count, !lhsPixels.isEmpty else {
            return 1.0
        }

        let totalDifference = zip(lhsPixels, rhsPixels).reduce(0.0) { result, pair in
            result + abs(Double(pair.0) - Double(pair.1))
        }

        return totalDifference / Double(lhsPixels.count) / 255.0
    }

    private func sampledGrayPixels(from image: CGImage, side: Int = 24) -> [UInt8]? {
        var pixels = [UInt8](repeating: 0, count: side * side)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let bitmapInfo = CGImageAlphaInfo.none.rawValue

        let success = pixels.withUnsafeMutableBytes { rawBuffer -> Bool in
            guard let baseAddress = rawBuffer.baseAddress else { return false }
            guard let context = CGContext(
                data: baseAddress,
                width: side,
                height: side,
                bitsPerComponent: 8,
                bytesPerRow: side,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            ) else {
                return false
            }

            context.interpolationQuality = .low
            context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }

        return success ? pixels : nil
    }
}

enum VideoAnalysisError: Error {
    case noFrames
}
