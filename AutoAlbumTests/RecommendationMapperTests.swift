import XCTest
@testable import AutoAlbum

final class RecommendationMapperTests: XCTestCase {
    func testDecodesRecommendationJSONAndPreservesHighlightOrdering() throws {
        let json = """
        {
          "theme": "朋友聚会",
          "recommended_style": "生活记录感",
          "title": "周末小聚",
          "subtitle": "把轻松的一天，剪成值得回看的回忆",
          "highlight_items": [
            {"id": "photo-1", "priority": 1, "reason": "适合开头"},
            {"id": "video-2", "priority": 2, "reason": "适合过渡"}
          ],
          "music_style": "温暖轻快",
          "transition_style": "柔和",
          "sharing_copy": "今天的快乐，都在这些碎片里。"
        }
        """

        let recommendation = try RecommendationMapper().decode(json)

        XCTAssertEqual(recommendation.theme, "朋友聚会")
        XCTAssertEqual(recommendation.recommendedStyle, .lifeLog)
        XCTAssertEqual(recommendation.highlightItems.first?.id, "photo-1")
        XCTAssertEqual(recommendation.highlightItems.last?.priority, 2)
    }

    func testDecodesRecommendationFromWrappedChatCompletionContent() throws {
        let json = """
        {
          "choices": [
            {
              "message": {
                "content": "{\\"theme\\":\\"周末日常\\",\\"recommended_style\\":\\"生活记录感\\",\\"title\\":\\"周末碎片\\",\\"subtitle\\":\\"把普通的一天，剪成值得回看的回忆\\",\\"highlight_items\\":[{\\"id\\":\\"photo-1\\",\\"priority\\":1,\\"reason\\":\\"开头\\"}],\\"music_style\\":\\"温暖轻快\\",\\"transition_style\\":\\"柔和\\",\\"sharing_copy\\":\\"周末快乐。\\"}"
              }
            }
          ]
        }
        """

        let recommendation = try RecommendationMapper().decode(json)

        XCTAssertEqual(recommendation.theme, "周末日常")
        XCTAssertEqual(recommendation.title, "周末碎片")
    }
}
