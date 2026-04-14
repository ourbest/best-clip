import Foundation
import SwiftUI

@MainActor
final class GenerationFlowViewModel: ObservableObject {
    @Published var availableAssets: [MediaAssetSnapshot] = Self.demoAssets()
    @Published var selectedAssetIDs: Set<String> = []
    @Published var recommendation: LLMRecommendation = Self.demoRecommendation()
    @Published var selectedStyle: RecommendedStyle = .lifeLog
    @Published var isGenerating = false
    @Published var exportURL: URL? = nil

    init() {
        if ProcessInfo.processInfo.arguments.contains("-stubRecommendation") {
            recommendation = Self.demoRecommendation()
        }
    }

    var selectedAssets: [MediaAssetSnapshot] {
        availableAssets.filter { selectedAssetIDs.contains($0.id) }
    }

    func summary() -> AssetSummary {
        AssetSummaryBuilder().build(from: selectedAssets.isEmpty ? availableAssets : selectedAssets)
    }

    func plan() -> CompositionPlan {
        CompositionPlanner().buildPlan(
            recommendation: recommendation,
            assets: selectedAssets.isEmpty ? availableAssets : selectedAssets
        )
    }

    func select(_ asset: MediaAssetSnapshot) {
        if selectedAssetIDs.contains(asset.id) {
            selectedAssetIDs.remove(asset.id)
        } else {
            selectedAssetIDs.insert(asset.id)
        }
    }

    func generatePreviewExport() {
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("memory-video.mov")
        let currentPlan = plan()
        let currentAssets = selectedAssets.isEmpty ? availableAssets : selectedAssets

        isGenerating = true
        defer { isGenerating = false }

        exportURL = try? VideoExportService().export(plan: currentPlan, assets: currentAssets, to: outputURL)
    }

    private static func demoRecommendation() -> LLMRecommendation {
        LLMRecommendation(
            theme: "周末日常",
            recommendedStyle: .lifeLog,
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
                speechText: nil,
                sourceURL: nil
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
                speechText: "let's go",
                sourceURL: nil
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
                speechText: nil,
                sourceURL: nil
            )
        ]
    }
}
