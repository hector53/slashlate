import XCTest
@testable import Slashlate

final class OpenRouterClientTests: XCTestCase {
    private func parse(_ json: String, statusCode: Int = 200) throws -> String {
        try OpenRouterTranslationService.parseResponse(data: Data(json.utf8), statusCode: statusCode)
    }

    private func assertError(
        _ expected: TranslationError,
        json: String,
        statusCode: Int = 200,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try parse(json, statusCode: statusCode), file: file, line: line) { error in
            XCTAssertEqual(error as? TranslationError, expected, file: file, line: line)
        }
    }

    func testParsesValidResponse() throws {
        let json = #"{"choices":[{"message":{"role":"assistant","content":"Hello."}}]}"#
        XCTAssertEqual(try parse(json), "Hello.")
    }

    func testTrimsOuterWhitespaceButKeepsInternalLineBreaks() throws {
        let json = #"{"choices":[{"message":{"content":"\n  First line.\n\nSecond line.  \n"}}]}"#
        XCTAssertEqual(try parse(json), "First line.\n\nSecond line.")
    }

    func testMissingChoicesIsInvalidResponse() {
        assertError(.invalidResponse, json: #"{"id":"gen-123"}"#)
    }

    func testEmptyChoicesIsInvalidResponse() {
        assertError(.invalidResponse, json: #"{"choices":[]}"#)
    }

    func testMissingContentIsInvalidResponse() {
        assertError(.invalidResponse, json: #"{"choices":[{"message":{"role":"assistant"}}]}"#)
    }

    func testEmptyContentIsEmptyResponse() {
        assertError(.emptyResponse, json: #"{"choices":[{"message":{"content":"   \n"}}]}"#)
    }

    func testInvalidJSONIsInvalidResponse() {
        assertError(.invalidResponse, json: "not json")
    }

    func testHTTPStatusMapping() {
        assertError(.authenticationFailed, json: "{}", statusCode: 401)
        assertError(.insufficientCredits, json: "{}", statusCode: 402)
        assertError(.rateLimited, json: "{}", statusCode: 429)
        assertError(.serverError(statusCode: 502), json: "{}", statusCode: 502)
    }

    func testErrorInsideSuccessfulBodyIsReported() {
        assertError(.rateLimited, json: #"{"error":{"code":429,"message":"slow down"}}"#)
    }

    func testTransportErrorMapping() {
        XCTAssertEqual(OpenRouterTranslationService.mapTransportError(URLError(.timedOut)), .timedOut)
        XCTAssertEqual(
            OpenRouterTranslationService.mapTransportError(URLError(.notConnectedToInternet)),
            .networkUnavailable
        )
    }

    func testRequestShape() throws {
        let request = try OpenRouterTranslationService.makeRequest(text: "hola mundo", apiKey: "test-key")

        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url, OpenRouterConfiguration.endpoint)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-key")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(request.timeoutInterval, OpenRouterConfiguration.timeout)

        let body = try XCTUnwrap(request.httpBody)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(object["model"] as? String, OpenRouterConfiguration.model)

        let messages = try XCTUnwrap(object["messages"] as? [[String: String]])
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0]["role"], "system")
        XCTAssertEqual(messages[0]["content"], TranslationPrompt.system)
        XCTAssertEqual(messages[1], ["role": "user", "content": "hola mundo"])
    }

    func testMissingAPIKeyFailsBeforeAnyRequest() async {
        let service = OpenRouterTranslationService(apiKeyProvider: { nil })

        do {
            _ = try await service.translate("hola")
            XCTFail("Expected missingAPIKey")
        } catch {
            XCTAssertEqual(error as? TranslationError, .missingAPIKey)
        }
    }

    func testErrorMessagesNeverContainAPIKey() {
        let errors: [TranslationError] = [
            .missingAPIKey, .keychainFailure, .networkUnavailable, .timedOut,
            .authenticationFailed, .insufficientCredits, .rateLimited,
            .serverError(statusCode: 500), .invalidResponse, .emptyResponse
        ]

        for error in errors {
            XCTAssertFalse(error.localizedDescription.contains("sk-or-"))
        }
    }
}
