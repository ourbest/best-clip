import Foundation
import SwiftUI

enum GenerationStage: Equatable {
    case idle
    case preparing
    case exporting
    case finished

    var title: String {
        switch self {
        case .idle:
            return "准备中"
        case .preparing:
            return "分析素材"
        case .exporting:
            return "导出视频"
        case .finished:
            return "已完成"
        }
    }

    var subtitle: String {
        switch self {
        case .idle:
            return "选择素材后就可以开始生成。"
        case .preparing:
            return "正在整理素材摘要并请求推荐。"
        case .exporting:
            return "正在把时间线渲染成可分享的视频。"
        case .finished:
            return "可以预览、分享或保存到相册。"
        }
    }

    var progress: Double {
        switch self {
        case .idle:
            return 0.0
        case .preparing:
            return 0.55
        case .exporting:
            return 0.85
        case .finished:
            return 1.0
        }
    }
}

struct LaunchConfiguration {
    let isUITesting: Bool
    let stubRecommendationStyle: RecommendedStyle?

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        isUITesting = arguments.contains("-uiTesting")
        stubRecommendationStyle = Self.parseStubRecommendationStyle(from: arguments)
    }

    private static func parseStubRecommendationStyle(from arguments: [String]) -> RecommendedStyle? {
        guard let flagIndex = arguments.firstIndex(of: "-stubRecommendation") else { return nil }
        let valueIndex = arguments.index(after: flagIndex)
        guard valueIndex < arguments.endIndex else { return nil }
        return RecommendedStyle(rawValue: arguments[valueIndex])
    }
}

@MainActor
final class GenerationFlowViewModel: ObservableObject {
    private let launchConfiguration: LaunchConfiguration
    private var settingsStore: SettingsStore
    private var pipeline: MemoryVideoPipeline
    private let mediaImporter: MediaSelectionImporting
    private let videoSaver = VideoPhotoLibrarySaver()
    @Published var availableAssets: [MediaAssetSnapshot] = []
    @Published var selectedAssetIDs: Set<String> = []
    @Published var recommendation: LLMRecommendation = LLMRecommendation(
        theme: "",
        recommendedStyle: .lifeLog,
        title: "",
        subtitle: "",
        highlightItems: [],
        musicStyle: "",
        transitionStyle: "",
        sharingCopy: ""
    )
    @Published var selectedStyle: RecommendedStyle = .lifeLog
    @Published var isGenerating = false
    @Published var exportURL: URL? = nil
    @Published var isImporting = false
    @Published var importError: String? = nil
    @Published var saveStatus: String? = nil
    @Published var generationStage: GenerationStage = .idle
    @Published var clusters: [RecommendationCluster] = []
    @Published var settingsModelName: String
    @Published var settingsAPIKey: String

    init(
        launchArguments: [String] = ProcessInfo.processInfo.arguments,
        settingsStore: SettingsStore? = nil,
        pipeline: MemoryVideoPipeline? = nil,
        mediaImporter: MediaSelectionImporting? = nil
    ) {
        launchConfiguration = LaunchConfiguration(arguments: launchArguments)
        self.settingsStore = settingsStore ?? SettingsStore(fileURL: Self.defaultSettingsURL())
        self.mediaImporter = mediaImporter ?? PhotosPickerAssetImporter()
        availableAssets = launchConfiguration.isUITesting ? Self.demoAssets() : []
        let recommendedStyle = launchConfiguration.stubRecommendationStyle ?? .lifeLog
        recommendation = Self.demoRecommendation(recommendedStyle: recommendedStyle)
        selectedStyle = recommendedStyle
        settingsModelName = self.settingsStore.modelName
        settingsAPIKey = self.settingsStore.apiKey

        if let pipeline {
            self.pipeline = pipeline
        } else {
            self.pipeline = Self.makePipeline(from: self.settingsStore)
        }
    }

    var selectedAssets: [MediaAssetSnapshot] {
        availableAssets.filter { selectedAssetIDs.contains($0.id) }
    }

    func summary() -> AssetSummary {
        let assets = effectiveAssets()
        return AssetSummaryBuilder().build(from: assets)
    }

    func plan() -> CompositionPlan {
        let assets = effectiveAssets()
        CompositionPlanner().buildPlan(
            recommendation: effectiveRecommendation,
            assets: assets
        )
    }

    func select(_ asset: MediaAssetSnapshot) {
        if selectedAssetIDs.contains(asset.id) {
            selectedAssetIDs.remove(asset.id)
        } else {
            selectedAssetIDs.insert(asset.id)
        }
    }

    func saveSettings() {
        settingsStore.modelName = settingsModelName
        settingsStore.apiKey = settingsAPIKey
        settingsStore.save()
        pipeline = Self.makePipeline(from: settingsStore)
        saveStatus = "设置已保存"
    }

    func importSelection(_ items: [any MediaSelectionItem]) async {
        guard !items.isEmpty else { return }

        isImporting = true
        importError = nil
        defer { isImporting = false }

        do {
            let importedAssets = try await mediaImporter.importSnapshots(from: items)
            availableAssets = importedAssets
            selectedAssetIDs = Set(importedAssets.map(\.id))
        } catch {
            importError = "导入失败：\(error.localizedDescription)"
        }
    }

    func generatePreviewExport() {
        Task { @MainActor in
            await self.generatePreviewExportAsync()
        }
    }

    func generatePreviewExportAsync() async {
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("memory-video.mov")
        let currentAssets = effectiveAssets()
        let currentPlan = CompositionPlanner().buildPlan(
            recommendation: effectiveRecommendation,
            assets: currentAssets
        )

        isGenerating = true
        generationStage = .preparing
        defer { isGenerating = false }

        if launchConfiguration.isUITesting {
            exportURL = Self.makeStubExportFile(at: outputURL)
            generationStage = .finished
            return
        }

            if let result = try? await pipeline.generate(
                from: currentAssets,
                to: outputURL,
                preferredStyle: selectedStyle
            ) {
                recommendation = result.recommendation
                clusters = result.clusters
                exportURL = result.exportURL
                generationStage = .finished
                return
            }

        generationStage = .exporting
        exportURL = try? await VideoExportService().export(plan: currentPlan, assets: currentAssets, to: outputURL)
        generationStage = .finished
    }

    func saveExportToPhotos() {
        guard let exportURL else { return }

        Task {
            do {
                try await videoSaver.saveVideo(at: exportURL)
                await MainActor.run {
                    self.saveStatus = "已保存到相册"
                }
            } catch {
                await MainActor.run {
                    self.saveStatus = "保存失败：\(error.localizedDescription)"
                }
            }
        }
    }

    private var effectiveRecommendation: LLMRecommendation {
        guard recommendation.recommendedStyle != selectedStyle else { return recommendation }

        return LLMRecommendation(
            theme: recommendation.theme,
            recommendedStyle: selectedStyle,
            title: recommendation.title,
            subtitle: recommendation.subtitle,
            highlightItems: recommendation.highlightItems,
            musicStyle: recommendation.musicStyle,
            transitionStyle: recommendation.transitionStyle,
            sharingCopy: recommendation.sharingCopy
        )
    }

    private func effectiveAssets() -> [MediaAssetSnapshot] {
        let sourceAssets = selectedAssets.isEmpty ? availableAssets : selectedAssets
        return AssetSelectionFilter().filter(sourceAssets)
    }

    private static func makeStubExportFile(at url: URL) -> URL? {
        let directoryURL = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }

        guard FileManager.default.createFile(atPath: url.path, contents: Data(), attributes: nil) else {
            return nil
        }

        return url
    }

    private static func defaultSettingsURL() -> URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return directory.appendingPathComponent("AutoAlbum/settings.json")
    }

    private static func makePipeline(from settingsStore: SettingsStore) -> MemoryVideoPipeline {
        guard !settingsStore.apiKey.isEmpty else {
            return MemoryVideoPipeline(recommendationClient: FailingRecommendationClient())
        }

        let baseURL = URL(string: "https://api.openai.com")!
        let client = LLMClient(
            baseURL: baseURL,
            apiKey: settingsStore.apiKey,
            modelName: settingsStore.modelName
        )
        return MemoryVideoPipeline(recommendationClient: client)
    }

    private static func demoRecommendation(recommendedStyle: RecommendedStyle) -> LLMRecommendation {
        LLMRecommendation(
            theme: "周末日常",
            recommendedStyle: recommendedStyle,
            title: "周末碎片",
            subtitle: "把普通的一天，剪成值得回看的回忆",
            highlightItems: [
                .init(id: "asset-1", priority: 1, reason: "适合开头"),
                .init(id: "asset-2", priority: 2, reason: "适合过渡"),
                .init(id: "asset-3", priority: 3, reason: "适合收尾")
            ],
            musicStyle: "轻快温暖",
            transitionStyle: "柔和",
            sharingCopy: "周末的这些小片段，拼起来就是我喜欢的生活。"
        )
    }

    private static func demoAssets() -> [MediaAssetSnapshot] {
        [
            MediaAssetSnapshot(
                id: "asset-1",
                kind: .photo,
                timestamp: Date(timeIntervalSince1970: 1_700_300_000),
                duration: nil,
                faces: 2,
                scene: "restaurant",
                sharpness: 0.94,
                stability: 0.88,
                ocrText: "happy sunday",
                speechText: nil
            ),
            MediaAssetSnapshot(
                id: "asset-2",
                kind: .video,
                timestamp: Date(timeIntervalSince1970: 1_700_300_120),
                duration: 8,
                faces: 1,
                scene: "street",
                sharpness: 0.81,
                stability: 0.71,
                ocrText: nil,
                speechText: "let's go"
            ),
            MediaAssetSnapshot(
                id: "asset-3",
                kind: .photo,
                timestamp: Date(timeIntervalSince1970: 1_700_300_240),
                duration: nil,
                faces: 3,
                scene: "park",
                sharpness: 0.89,
                stability: 0.91,
                ocrText: nil,
                speechText: nil
            )
        ]
    }
}

private struct FailingRecommendationClient: RecommendationProviding {
    func requestRecommendation(for summary: AssetSummary) async throws -> LLMRecommendation {
        throw URLError(.cannotConnectToHost)
    }
}
