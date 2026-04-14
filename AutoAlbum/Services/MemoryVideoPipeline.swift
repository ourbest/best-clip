import Foundation

protocol RecommendationProviding {
    func requestRecommendation(for summary: AssetSummary) async throws -> LLMRecommendation
}

extension LLMClient: RecommendationProviding {}

struct MemoryVideoGenerationResult: Equatable {
    let summary: AssetSummary
    let recommendation: LLMRecommendation
    let plan: CompositionPlan
    let exportURL: URL
}

final class MemoryVideoPipeline {
    private let summaryBuilder: AssetSummaryBuilder
    private let recommendationClient: RecommendationProviding
    private let exportService: VideoExporting
    private let fallbackStyle: RecommendedStyle

    init(
        summaryBuilder: AssetSummaryBuilder = AssetSummaryBuilder(),
        recommendationClient: RecommendationProviding,
        exportService: VideoExporting = VideoExportService(),
        fallbackStyle: RecommendedStyle = .lifeLog
    ) {
        self.summaryBuilder = summaryBuilder
        self.recommendationClient = recommendationClient
        self.exportService = exportService
        self.fallbackStyle = fallbackStyle
    }

    func generate(from assets: [MediaAssetSnapshot], to destinationURL: URL) async throws -> MemoryVideoGenerationResult {
        try await generate(from: assets, to: destinationURL, preferredStyle: nil)
    }

    func generate(
        from assets: [MediaAssetSnapshot],
        to destinationURL: URL,
        preferredStyle: RecommendedStyle?
    ) async throws -> MemoryVideoGenerationResult {
        let summary = summaryBuilder.build(from: assets)
        let recommendation = applyPreferredStyle(try await loadRecommendation(for: summary), preferredStyle: preferredStyle)
        let plan = CompositionPlanner().buildPlan(recommendation: recommendation, assets: assets)
        let exportURL = try await exportService.export(plan: plan, assets: assets, to: destinationURL)

        return MemoryVideoGenerationResult(
            summary: summary,
            recommendation: recommendation,
            plan: plan,
            exportURL: exportURL
        )
    }

    private func loadRecommendation(for summary: AssetSummary) async throws -> LLMRecommendation {
        do {
            return try await recommendationClient.requestRecommendation(for: summary)
        } catch {
            return fallbackRecommendation(for: summary)
        }
    }

    private func fallbackRecommendation(for summary: AssetSummary) -> LLMRecommendation {
        let highlightItems = summary.highlightItems.prefix(3).enumerated().map { index, item in
            RecommendationHighlightItem(
                id: item.id,
                priority: index + 1,
                reason: item.reason
            )
        }

        return LLMRecommendation(
            theme: summary.recommendedTheme,
            recommendedStyle: fallbackStyle,
            title: summary.recommendedTheme,
            subtitle: "从这组素材中整理出一条可分享的回忆。",
            highlightItems: highlightItems,
            musicStyle: "轻快温暖",
            transitionStyle: "柔和",
            sharingCopy: "把这些片段留作回忆。"
        )
    }

    private func applyPreferredStyle(_ recommendation: LLMRecommendation, preferredStyle: RecommendedStyle?) -> LLMRecommendation {
        guard let preferredStyle else { return recommendation }
        guard recommendation.recommendedStyle != preferredStyle else { return recommendation }

        return LLMRecommendation(
            theme: recommendation.theme,
            recommendedStyle: preferredStyle,
            title: recommendation.title,
            subtitle: recommendation.subtitle,
            highlightItems: recommendation.highlightItems,
            musicStyle: recommendation.musicStyle,
            transitionStyle: recommendation.transitionStyle,
            sharingCopy: recommendation.sharingCopy
        )
    }
}
