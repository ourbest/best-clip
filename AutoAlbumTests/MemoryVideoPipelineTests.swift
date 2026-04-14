import AVFoundation
import XCTest
import UIKit
@testable import AutoAlbum

final class MemoryVideoPipelineTests: XCTestCase {
    func testRunsSummaryRecommendationPlanAndExportInOrder() async throws {
        let assets = [
            MediaAssetSnapshot(
                id: "photo-1",
                kind: .photo,
                timestamp: Date(timeIntervalSince1970: 1_700_000_000),
                duration: nil,
                faces: 2,
                scene: "restaurant",
                sharpness: 0.95,
                stability: 0.9,
                ocrText: "happy birthday",
                speechText: nil
            )
        ]

        let client = FakeRecommendationClient()
        let exporter = FakeExportService()
        let pipeline = MemoryVideoPipeline(
            recommendationClient: client,
            exportService: exporter
        )

        let destinationURL = FileManager.default.temporaryDirectory.appendingPathComponent("memory-video.mov")
        let result = try await pipeline.generate(from: assets, to: destinationURL)

        XCTAssertEqual(client.requestedSummaries.first?.recommendedTheme, "周末日常")
        XCTAssertEqual(exporter.exportedPlans.first?.title, "周末碎片")
        XCTAssertEqual(result.exportURL, destinationURL)
        XCTAssertEqual(result.plan.sections.first?.assetID, "photo-1")
    }

    func testFallsBackToLocalRecommendationWhenClientFails() async throws {
        let assets = [
            MediaAssetSnapshot(
                id: "photo-1",
                kind: .photo,
                timestamp: Date(timeIntervalSince1970: 1_700_000_000),
                duration: nil,
                faces: 1,
                scene: "park",
                sharpness: 0.8,
                stability: 0.7,
                ocrText: nil,
                speechText: nil
            )
        ]

        let client = FailingRecommendationClient()
        let exporter = FakeExportService()
        let pipeline = MemoryVideoPipeline(
            recommendationClient: client,
            exportService: exporter
        )

        let destinationURL = FileManager.default.temporaryDirectory.appendingPathComponent("fallback.mov")
        let result = try await pipeline.generate(from: assets, to: destinationURL)

        XCTAssertEqual(result.recommendation.theme, "周末日常")
        XCTAssertEqual(result.recommendation.recommendedStyle, .lifeLog)
        XCTAssertEqual(exporter.exportedPlans.first?.title, "周末日常")
    }

    func testImportsSelectionIntoAssets() async throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 24, height: 24))
        let image = renderer.image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: CGSize(width: 24, height: 24)))
        }
        let data = try XCTUnwrap(image.pngData())

        let viewModel = GenerationFlowViewModel(
            launchArguments: [],
            settingsStore: SettingsStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("settings.json"), secretStore: InMemorySecretStore()),
            mediaImporter: PhotosPickerAssetImporter(analyzer: MediaAssetAnalyzer())
        )

        await viewModel.importSelection([FakeSelectionItem(data: data)])

        XCTAssertEqual(viewModel.availableAssets.count, 1)
        XCTAssertEqual(viewModel.selectedAssetIDs.count, 1)
        XCTAssertNotNil(viewModel.availableAssets.first?.sourceURL)
        XCTAssertNotNil(viewModel.availableAssets.first?.previewURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: viewModel.availableAssets.first?.previewURL?.path ?? ""))
    }

    func testImportsVideoSelectionWithGeneratedCoverImage() async throws {
        let videoURL = try makeTestVideoURL()
        let importer = PhotosPickerAssetImporter(analyzer: MediaAssetAnalyzer())

        let snapshots = try await importer.importSnapshots(from: [FakeSelectionItem(fileURL: videoURL)])

        let snapshot = try XCTUnwrap(snapshots.first)
        XCTAssertEqual(snapshot.kind, .video)
        XCTAssertNotNil(snapshot.previewURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: snapshot.previewURL?.path ?? ""))
    }

    func testFiltersLowQualityAssetsBeforeGeneratingPlan() async throws {
        let goodPhoto = MediaAssetSnapshot(
            id: "good-photo",
            kind: .photo,
            timestamp: Date(timeIntervalSince1970: 1_700_700_000),
            duration: nil,
            faces: 2,
            scene: "restaurant",
            sharpness: 0.94,
            stability: 0.9,
            ocrText: "birthday",
            speechText: nil
        )

        let weakVideo = MediaAssetSnapshot(
            id: "weak-video",
            kind: .video,
            timestamp: Date(timeIntervalSince1970: 1_700_700_030),
            duration: 14.0,
            faces: 0,
            scene: "street",
            sharpness: 0.34,
            stability: 0.22,
            motion: 0.91,
            ocrText: nil,
            speechText: nil
        )

        let client = FakeRecommendationClient()
        let exporter = FakeExportService()
        let pipeline = MemoryVideoPipeline(
            recommendationClient: client,
            exportService: exporter
        )

        let destinationURL = FileManager.default.temporaryDirectory.appendingPathComponent("filtered.mov")
        let result = try await pipeline.generate(from: [goodPhoto, weakVideo], to: destinationURL)

        XCTAssertEqual(result.summary.highlightItems.first?.id, "good-photo")
        XCTAssertEqual(exporter.exportedAssets.first?.map(\.id), ["good-photo"])
        XCTAssertFalse(result.plan.sections.contains(where: { $0.assetID == "weak-video" }))
    }
}

private final class FakeRecommendationClient: RecommendationProviding {
    private(set) var requestedSummaries: [AssetSummary] = []

    func requestRecommendation(for summary: AssetSummary) async throws -> LLMRecommendation {
        requestedSummaries.append(summary)
        return LLMRecommendation(
            theme: "周末日常",
            recommendedStyle: .lifeLog,
            title: "周末碎片",
            subtitle: "把普通的一天，剪成值得回看的回忆",
            highlightItems: summary.highlightItems.map {
                .init(id: $0.id, priority: $0.priority, reason: $0.reason)
            },
            musicStyle: "轻快温暖",
            transitionStyle: "柔和",
            sharingCopy: "周末的这些小片段，拼起来就是我喜欢的生活。"
        )
    }
}

private final class FailingRecommendationClient: RecommendationProviding {
    func requestRecommendation(for summary: AssetSummary) async throws -> LLMRecommendation {
        throw URLError(.cannotFindHost)
    }
}

private final class FakeExportService: VideoExporting {
    private(set) var exportedPlans: [CompositionPlan] = []
    private(set) var exportedAssets: [[MediaAssetSnapshot]] = []

    func export(plan: CompositionPlan, assets: [MediaAssetSnapshot], to destinationURL: URL) async throws -> URL {
        exportedPlans.append(plan)
        exportedAssets.append(assets)
        return destinationURL
    }
}

private struct FakeSelectionItem: MediaSelectionItem {
    let fileURL: URL?
    let data: Data?

    init(data: Data) {
        self.fileURL = nil
        self.data = data
    }

    init(fileURL: URL) {
        self.fileURL = fileURL
        self.data = nil
    }

    func loadFileURL() async throws -> URL? {
        fileURL
    }

    func loadData() async throws -> Data? {
        data
    }
}

private func makeTestVideoURL() throws -> URL {
    let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("autoclip-test-video.mov")
    try? FileManager.default.removeItem(at: outputURL)

    let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
    let settings: [String: Any] = [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: 64,
        AVVideoHeightKey: 64
    ]

    let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
    input.expectsMediaDataInRealTime = false

    let sourceAttributes: [String: Any] = [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
        kCVPixelBufferWidthKey as String: 64,
        kCVPixelBufferHeightKey as String: 64
    ]

    let adaptor = AVAssetWriterInputPixelBufferAdaptor(
        assetWriterInput: input,
        sourcePixelBufferAttributes: sourceAttributes
    )

    writer.add(input)
    writer.startWriting()
    writer.startSession(atSourceTime: .zero)

    let image = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64)).image { context in
        UIColor.systemBlue.setFill()
        context.fill(CGRect(origin: .zero, size: CGSize(width: 64, height: 64)))
        UIColor.white.setFill()
        context.fill(CGRect(x: 16, y: 16, width: 32, height: 32))
    }

    let pixelBuffer = try makePixelBuffer(from: image, size: CGSize(width: 64, height: 64))
    guard adaptor.append(pixelBuffer, withPresentationTime: .zero) else {
        throw NSError(domain: "AutoAlbumTests", code: -3)
    }
    input.markAsFinished()

    let semaphore = DispatchSemaphore(value: 0)
    writer.finishWriting {
        semaphore.signal()
    }
    semaphore.wait()

    guard writer.status == .completed else {
        throw writer.error ?? NSError(domain: "AutoAlbumTests", code: -4)
    }

    return outputURL
}

private func makePixelBuffer(from image: UIImage, size: CGSize) throws -> CVPixelBuffer {
    let attributes = [
        kCVPixelBufferCGImageCompatibilityKey as String: true,
        kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
    ] as CFDictionary

    var pixelBuffer: CVPixelBuffer?
    let status = CVPixelBufferCreate(
        kCFAllocatorDefault,
        Int(size.width),
        Int(size.height),
        kCVPixelFormatType_32ARGB,
        attributes,
        &pixelBuffer
    )

    guard status == kCVReturnSuccess, let pixelBuffer else {
        throw NSError(domain: "AutoAlbumTests", code: -1)
    }

    CVPixelBufferLockBaseAddress(pixelBuffer, [])
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

    guard let context = CGContext(
        data: CVPixelBufferGetBaseAddress(pixelBuffer),
        width: Int(size.width),
        height: Int(size.height),
        bitsPerComponent: 8,
        bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
    ) else {
        throw NSError(domain: "AutoAlbumTests", code: -2)
    }

    context.draw(image.cgImage!, in: CGRect(origin: .zero, size: size))
    return pixelBuffer
}
