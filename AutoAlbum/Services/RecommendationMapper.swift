import Foundation

struct RecommendationMapper {
    func decode(_ rawResponse: String) throws -> LLMRecommendation {
        let jsonString = try extractRecommendationJSONString(from: rawResponse)
        let data = Data(jsonString.utf8)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(LLMRecommendation.self, from: data)
    }

    private func extractRecommendationJSONString(from rawResponse: String) throws -> String {
        let trimmed = rawResponse.trimmingCharacters(in: .whitespacesAndNewlines)

        if let fenced = extractFencedJSON(from: trimmed) {
            return fenced
        }

        if let wrapperContent = extractWrappedContent(from: trimmed) {
            if let fenced = extractFencedJSON(from: wrapperContent) {
                return fenced
            }
            return wrapperContent
        }

        return trimmed
    }

    private func extractFencedJSON(from text: String) -> String? {
        let pattern = #"```(?:json)?\s*([\s\S]*?)\s*```"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              let captureRange = Range(match.range(at: 1), in: text) else {
            return nil
        }

        return text[captureRange].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractWrappedContent(from text: String) -> String? {
        guard let data = text.data(using: .utf8) else { return nil }
        guard let object = try? JSONSerialization.jsonObject(with: data) else { return nil }

        if let dictionary = object as? [String: Any] {
            if let content = dictionary["content"] as? String {
                return content
            }

            if let choices = dictionary["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let message = firstChoice["message"] as? [String: Any],
               let content = message["content"] as? String {
                return content
            }
        }

        if let array = object as? [[String: Any]],
           let first = array.first,
           let content = first["content"] as? String {
            return content
        }

        return nil
    }
}
