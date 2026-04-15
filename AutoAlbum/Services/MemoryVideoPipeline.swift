import Foundation

protocol RecommendationProviding {
    func requestRecommendation(for summary: AssetSummary) async throws -> LLMRecommendation
}

extension LLMClient: RecommendationProviding {}

struct MemoryVideoGenerationResult: Equatable {
    let summary: AssetSummary
    let recommendation: LLMRecommendation
    let clusters: [RecommendationCluster]
    let plan: CompositionPlan
    let exportURL: URL
}

final class MemoryVideoPipeline {
    private let summaryBuilder: AssetSummaryBuilder
    private let selectionFilter: AssetSelectionFilter
    private let recommendationNormalizer: RecommendationNormalizer
    private let recommendationClusterer: RecommendationClusterer
    private let recommendationClient: RecommendationProviding
    private let exportService: VideoExporting
    private let fallbackStyle: RecommendedStyle

    init(
        summaryBuilder: AssetSummaryBuilder = AssetSummaryBuilder(),
        selectionFilter: AssetSelectionFilter = AssetSelectionFilter(),
        recommendationNormalizer: RecommendationNormalizer = RecommendationNormalizer(),
        recommendationClusterer: RecommendationClusterer = RecommendationClusterer(),
        recommendationClient: RecommendationProviding,
        exportService: VideoExporting = VideoExportService(),
        fallbackStyle: RecommendedStyle = .lifeLog
    ) {
        self.summaryBuilder = summaryBuilder
        self.selectionFilter = selectionFilter
        self.recommendationNormalizer = recommendationNormalizer
        self.recommendationClusterer = recommendationClusterer
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
        let eligibleAssets = selectionFilter.filter(assets)
        let summary = summaryBuilder.build(from: eligibleAssets)
        let recommendation = recommendationNormalizer.normalize(
            applyPreferredStyle(try await loadRecommendation(for: summary), preferredStyle: preferredStyle),
            summary: summary
        )
        let clusters = recommendationClusterer.cluster(highlights: recommendation.highlightItems, summary: summary)
        let plan = CompositionPlanner().buildPlan(recommendation: recommendation, assets: eligibleAssets)
        let exportURL = try await exportService.export(plan: plan, assets: eligibleAssets, to: destinationURL)

        return MemoryVideoGenerationResult(
            summary: summary,
            recommendation: recommendation,
            clusters: clusters,
            plan: plan,
            exportURL: exportURL
        )
    }

    private func loadRecommendation(for summary: AssetSummary) async throws -> LLMRecommendation {
        try await recommendationClient.requestRecommendation(for: summary)
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
