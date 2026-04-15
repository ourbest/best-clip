import Foundation

protocol LLMClientProtocol {
    func requestRecommendation(for summary: AssetSummary) async throws -> LLMRecommendation
}

final class LLMClient: LLMClientProtocol {
    enum ClientError: LocalizedError {
        case invalidResponse
        case httpError(Int)

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "返回格式无效"
            case .httpError(let statusCode):
                return "请求失败，HTTP \(statusCode)"
            }
        }
    }

    private let session: URLSession
    private let baseURL: URL
    private let apiKey: String
    private let modelName: String

    init(
        session: URLSession = .shared,
        baseURL: URL,
        apiKey: String,
        modelName: String
    ) {
        self.session = session
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.modelName = modelName
    }

    func requestRecommendation(for summary: AssetSummary) async throws -> LLMRecommendation {
        let prompt = RecommendationPrompt.make(from: summary)
        let request = try makeRequest(prompt: prompt)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClientError.invalidResponse
        }
        guard 200..<300 ~= httpResponse.statusCode else {
            throw ClientError.httpError(httpResponse.statusCode)
        }

        let rawResponse = String(decoding: data, as: UTF8.self)
        return try RecommendationMapper().decode(rawResponse)
    }

    func validateConfiguration() async throws {
        _ = try await requestRecommendation(
            for: AssetSummary(
                recommendedTheme: "配置验证",
                highlightItems: []
            )
        )
    }

    private func makeRequest(prompt: String) throws -> URLRequest {
        var request = URLRequest(url: baseURL.appendingPathComponent("v1/chat/completions"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": modelName,
            "temperature": 0.2,
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        return request
    }
}
