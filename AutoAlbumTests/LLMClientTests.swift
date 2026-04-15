import XCTest
@testable import AutoAlbum

final class LLMClientTests: XCTestCase {
    func testBuildsRequestAndDecodesRecommendation() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        let responseJSON = """
        {
          "theme": "生日聚会",
          "recommended_style": "生活记录感",
          "title": "生日小记",
          "subtitle": "把热闹的一天留在回忆里",
          "highlight_items": [
            {"id": "photo-1", "priority": 1, "reason": "适合作为开头"}
          ],
          "music_style": "温暖轻快",
          "transition_style": "柔和",
          "sharing_copy": "生日快乐。"
        }
        """

        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-key")

            let bodyData = try XCTUnwrap(request.httpBody)
            let body = try XCTUnwrap(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
            XCTAssertEqual(body["model"] as? String, "gpt-4o-mini")

            let messages = body["messages"] as? [[String: Any]]
            let prompt = messages?.first?["content"] as? String
            XCTAssertTrue(prompt?.contains("生日聚会") == true)

            let data = Data(responseJSON.utf8)
            return HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!.with(data: data)
        }

        let client = LLMClient(
            session: session,
            baseURL: URL(string: "https://example.com")!,
            apiKey: "test-key",
            modelName: "gpt-4o-mini"
        )

        let summary = AssetSummary(
            recommendedTheme: "生日聚会",
            highlightItems: [
                .init(id: "photo-1", priority: 1, reason: "适合作为开头")
            ]
        )

        let recommendation = try await client.requestRecommendation(for: summary)

        XCTAssertEqual(recommendation.theme, "生日聚会")
        XCTAssertEqual(recommendation.highlightItems.first?.id, "photo-1")
    }

    func testValidateConfigurationUsesTheConfiguredEndpoint() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.absoluteString, "https://proxy.example.com/v1/chat/completions")
            XCTAssertEqual(request.httpMethod, "POST")

            let bodyData = try XCTUnwrap(request.httpBody)
            let body = try XCTUnwrap(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
            XCTAssertEqual(body["model"] as? String, "claude-sonnet-4")

            let responseJSON = """
            {
              "theme": "配置验证",
              "recommended_style": "生活记录感",
              "title": "配置成功",
              "subtitle": "可以开始生成",
              "highlight_items": [],
              "music_style": "温暖轻快",
              "transition_style": "柔和",
              "sharing_copy": "配置验证通过。"
            }
            """

            let data = Data(responseJSON.utf8)
            return HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!.with(data: data)
        }

        let client = LLMClient(
            session: session,
            baseURL: URL(string: "https://proxy.example.com")!,
            apiKey: "test-key",
            modelName: "claude-sonnet-4"
        )

        try await client.validateConfiguration()
    }

    func testValidateConfigurationSurfacesHttpFailure() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 401,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return response.with(data: Data(#"{"error":"unauthorized"}"#.utf8))
        }

        let client = LLMClient(
            session: session,
            baseURL: URL(string: "https://proxy.example.com")!,
            apiKey: "test-key",
            modelName: "claude-sonnet-4"
        )

        do {
            try await client.validateConfiguration()
            XCTFail("Expected validation to fail")
        } catch LLMClient.ClientError.httpError(let statusCode) {
            XCTAssertEqual(statusCode, 401)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

final class GenerationFlowViewModelTests: XCTestCase {
    func testUsesStubRecommendationStyleAndCreatesStubExportDuringUITesting() async {
        let viewModel = GenerationFlowViewModel(
            launchArguments: [
                "-uiTesting",
                "-stubRecommendation",
                "短视频爆款感"
            ]
        )

        XCTAssertEqual(viewModel.selectedStyle, .shortVideo)
        XCTAssertEqual(viewModel.recommendation.recommendedStyle, .shortVideo)

        await viewModel.generatePreviewExportAsync()

        XCTAssertEqual(viewModel.exportURL?.lastPathComponent, "memory-video.mov")
        XCTAssertEqual(viewModel.generationStage, .finished)
    }

    func testGeneratePreviewExportShowsFailureWhenRecommendationClientThrows() async {
        let store = SettingsStore(
            fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("failed-generation-settings.json"),
            secretStore: InMemorySecretStore()
        )
        var configured = store
        configured.provider = .openAI
        configured.baseURL = "https://example.com"
        configured.modelName = "gpt-4o-mini"
        configured.apiKey = "test-key"

        let viewModel = GenerationFlowViewModel(
            settingsStore: configured,
            pipeline: MemoryVideoPipeline(recommendationClient: FailingRecommendationClient())
        )
        viewModel.availableAssets = [
            .init(
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

        await viewModel.generatePreviewExportAsync()

        XCTAssertEqual(viewModel.generationStage, .failed)
        XCTAssertTrue(viewModel.generationErrorMessage?.contains("生成失败") == true)
        XCTAssertNil(viewModel.exportURL)
    }
}

private final class FailingRecommendationClient: RecommendationProviding {
    func requestRecommendation(for summary: AssetSummary) async throws -> LLMRecommendation {
        throw URLError(.cannotConnectToHost)
    }
}

final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> HTTPURLResponseWithData)?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let response = try handler(request)
            client?.urlProtocol(self, didReceive: response.response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: response.data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

struct HTTPURLResponseWithData {
    let response: HTTPURLResponse
    let data: Data
}

extension HTTPURLResponse {
    func with(data: Data) -> HTTPURLResponseWithData {
        HTTPURLResponseWithData(response: self, data: data)
    }
}
