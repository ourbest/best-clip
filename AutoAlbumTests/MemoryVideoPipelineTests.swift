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

    func testFallsBackToSingleBestAssetWhenAllAssetsAreLowQuality() async throws {
        let weakPhoto = MediaAssetSnapshot(
            id: "weak-photo",
            kind: .photo,
            timestamp: Date(timeIntervalSince1970: 1_700_710_000),
            duration: nil,
            faces: 0,
            scene: "parking",
            sharpness: 0.22,
            stability: 0.31,
            ocrText: nil,
            speechText: nil
        )

        let slightlyBetterVideo = MediaAssetSnapshot(
            id: "slightly-better-video",
            kind: .video,
            timestamp: Date(timeIntervalSince1970: 1_700_710_030),
            duration: 9.0,
            faces: 0,
            scene: "street",
            sharpness: 0.26,
            stability: 0.34,
            motion: 0.62,
            ocrText: nil,
            speechText: nil
        )

        let client = FakeRecommendationClient()
        let exporter = FakeExportService()
        let pipeline = MemoryVideoPipeline(
            recommendationClient: client,
            exportService: exporter
        )

        let destinationURL = FileManager.default.temporaryDirectory.appendingPathComponent("fallback-best.mov")
        let result = try await pipeline.generate(from: [weakPhoto, slightlyBetterVideo], to: destinationURL)

        XCTAssertEqual(result.summary.highlightItems.count, 1)
        XCTAssertEqual(result.summary.highlightItems.first?.id, "slightly-better-video")
        XCTAssertEqual(exporter.exportedAssets.first?.map(\.id), ["slightly-better-video"])
    }

    func testNormalizesEmptyRecommendationTitleAndSubtitle() async throws {
        let assets = [
            MediaAssetSnapshot(
                id: "photo-1",
                kind: .photo,
                timestamp: Date(timeIntervalSince1970: 1_700_720_000),
                duration: nil,
                faces: 2,
                scene: "park",
                sharpness: 0.91,
                stability: 0.88,
                ocrText: nil,
                speechText: nil
            )
        ]

        let client = EmptyTitleRecommendationClient()
        let exporter = FakeExportService()
        let pipeline = MemoryVideoPipeline(
            recommendationClient: client,
            exportService: exporter
        )

        let destinationURL = FileManager.default.temporaryDirectory.appendingPathComponent("normalized-title.mov")
        let result = try await pipeline.generate(from: assets, to: destinationURL)

        XCTAssertEqual(result.recommendation.title, "周末日常")
        XCTAssertEqual(result.recommendation.subtitle, "从这组素材中整理出一条可分享的回忆。")
    }

    func testTrimsOverlongRecommendationTitle() async throws {
        let assets = [
            MediaAssetSnapshot(
                id: "photo-1",
                kind: .photo,
                timestamp: Date(timeIntervalSince1970: 1_700_730_000),
                duration: nil,
                faces: 2,
                scene: "cafe",
                sharpness: 0.91,
                stability: 0.9,
                ocrText: nil,
                speechText: nil
            )
        ]

        let client = LongTitleRecommendationClient()
        let exporter = FakeExportService()
        let pipeline = MemoryVideoPipeline(
            recommendationClient: client,
            exportService: exporter
        )

        let destinationURL = FileManager.default.temporaryDirectory.appendingPathComponent("trimmed-title.mov")
        let result = try await pipeline.generate(from: assets, to: destinationURL)

        XCTAssertEqual(result.recommendation.title, "周末的一次很长的标题需要")
    }

    func testClustersHighlightsByKeywordAndFallsBackToThemeGroup() async throws {
        let assets = [
            MediaAssetSnapshot(
                id: "photo-1",
                kind: .photo,
                timestamp: Date(timeIntervalSince1970: 1_700_740_000),
                duration: nil,
                faces: 2,
                scene: "park",
                sharpness: 0.92,
                stability: 0.9,
                ocrText: nil,
                speechText: nil
            ),
            MediaAssetSnapshot(
                id: "video-2",
                kind: .video,
                timestamp: Date(timeIntervalSince1970: 1_700_740_030),
                duration: 10.0,
                faces: 1,
                scene: "street",
                sharpness: 0.84,
                stability: 0.8,
                motion: 0.18,
                ocrText: nil,
                speechText: "hello"
            ),
            MediaAssetSnapshot(
                id: "photo-3",
                kind: .photo,
                timestamp: Date(timeIntervalSince1970: 1_700_740_060),
                duration: nil,
                faces: 0,
                scene: "city",
                sharpness: 0.7,
                stability: 0.66,
                ocrText: nil,
                speechText: nil
            )
        ]

        let client = ClusteringRecommendationClient()
        let exporter = FakeExportService()
        let pipeline = MemoryVideoPipeline(
            recommendationClient: client,
            exportService: exporter
        )

        let destinationURL = FileManager.default.temporaryDirectory.appendingPathComponent("clustered.mov")
        let result = try await pipeline.generate(from: assets, to: destinationURL)

        XCTAssertEqual(result.clusters.first?.title, "开头")
        XCTAssertTrue(result.clusters.contains { $0.title == "承接" })
        XCTAssertTrue(result.clusters.contains { $0.title == "周末日常" })
    }

    func testRecommendationClustererUsesKeywordBucketsBeforeThemeFallback() {
        let clusterer = RecommendationClusterer()
        let summary = AssetSummary(
            recommendedTheme: "周末日常",
            highlightItems: [
                .init(id: "photo-1", priority: 1, reason: "适合开头"),
                .init(id: "video-2", priority: 2, reason: "适合过渡"),
                .init(id: "photo-3", priority: 3, reason: "无明显关键词")
            ]
        )

        let clusters = clusterer.cluster(
            highlights: [
                .init(id: "photo-1", priority: 1, reason: "适合开头"),
                .init(id: "video-2", priority: 2, reason: "适合过渡"),
                .init(id: "photo-3", priority: 3, reason: "无明显关键词")
            ],
            summary: summary
        )

        XCTAssertEqual(clusters.first?.title, "开头")
        XCTAssertTrue(clusters.contains { $0.title == "承接" })

        let fallbackClusters = clusterer.cluster(
            highlights: [
                .init(id: "photo-9", priority: 1, reason: "普通素材")
            ],
            summary: AssetSummary(recommendedTheme: "朋友聚会", highlightItems: [])
        )

        XCTAssertEqual(fallbackClusters.first?.title, "朋友聚会")
        XCTAssertEqual(fallbackClusters.first?.itemIDs, ["photo-9"])
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

private final class EmptyTitleRecommendationClient: RecommendationProviding {
    func requestRecommendation(for summary: AssetSummary) async throws -> LLMRecommendation {
        LLMRecommendation(
            theme: summary.recommendedTheme,
            recommendedStyle: .lifeLog,
            title: "",
            subtitle: "",
            highlightItems: summary.highlightItems.map {
                .init(id: $0.id, priority: $0.priority, reason: $0.reason)
            },
            musicStyle: "轻快温暖",
            transitionStyle: "柔和",
            sharingCopy: "把这些片段留作回忆。"
        )
    }
}

private final class LongTitleRecommendationClient: RecommendationProviding {
    func requestRecommendation(for summary: AssetSummary) async throws -> LLMRecommendation {
        LLMRecommendation(
            theme: summary.recommendedTheme,
            recommendedStyle: .lifeLog,
            title: "周末的一次很长的标题需要被截断",
            subtitle: "轻松记录",
            highlightItems: summary.highlightItems.map {
                .init(id: $0.id, priority: $0.priority, reason: $0.reason)
            },
            musicStyle: "轻快温暖",
            transitionStyle: "柔和",
            sharingCopy: "把这些片段留作回忆。"
        )
    }
}

private final class ClusteringRecommendationClient: RecommendationProviding {
    func requestRecommendation(for summary: AssetSummary) async throws -> LLMRecommendation {
        LLMRecommendation(
            theme: summary.recommendedTheme,
            recommendedStyle: .lifeLog,
            title: "周末日常",
            subtitle: "轻松记录",
            highlightItems: [
                .init(id: "photo-1", priority: 1, reason: "适合开头"),
                .init(id: "video-2", priority: 2, reason: "适合作为承接镜头"),
                .init(id: "photo-3", priority: 3, reason: "适合收尾")
            ],
            musicStyle: "轻快温暖",
            transitionStyle: "柔和",
            sharingCopy: "把这些片段留作回忆。"
        )
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
