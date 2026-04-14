import Foundation

struct RecommendationNormalizer {
    private let maxTitleLength: Int

    init(maxTitleLength: Int = 12) {
        self.maxTitleLength = maxTitleLength
    }

    func normalize(_ recommendation: LLMRecommendation, summary: AssetSummary) -> LLMRecommendation {
        LLMRecommendation(
            theme: recommendation.theme.isEmpty ? summary.recommendedTheme : recommendation.theme,
            recommendedStyle: recommendation.recommendedStyle,
            title: normalizedTitle(from: recommendation.title, fallback: summary.recommendedTheme),
            subtitle: normalizedSubtitle(from: recommendation.subtitle),
            highlightItems: recommendation.highlightItems,
            musicStyle: recommendation.musicStyle,
            transitionStyle: recommendation.transitionStyle,
            sharingCopy: recommendation.sharingCopy
        )
    }

    private func normalizedTitle(from title: String, fallback: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = trimmed.isEmpty ? fallback : trimmed
        return String(candidate.prefix(maxTitleLength))
    }

    private func normalizedSubtitle(from subtitle: String) -> String {
        let trimmed = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "从这组素材中整理出一条可分享的回忆。"
        }
        return trimmed
    }
}
