import Foundation

/// The single place to change OpenRouter settings.
enum OpenRouterConfiguration {
    static let model = "openai/gpt-5-nano"
    /// gpt-5-nano is a reasoning model. Minimal effort keeps a short
    /// translation within the ~1-2 second target. Set to nil to use the
    /// provider default.
    static let reasoningEffort: String? = "minimal"
    static let endpoint = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
    static let timeout: TimeInterval = 10
    static let appTitle = "Slashlate"
    static let referer = "https://github.com/hector53/slashlate"
}

struct OpenRouterTranslationService: TranslationService {
    private let apiKeyProvider: () throws -> String?
    private let session: URLSession

    init(apiKeyProvider: @escaping () throws -> String?) {
        self.apiKeyProvider = apiKeyProvider

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = OpenRouterConfiguration.timeout
        configuration.timeoutIntervalForResource = OpenRouterConfiguration.timeout
        configuration.waitsForConnectivity = false
        self.session = URLSession(configuration: configuration)
    }

    func translate(_ text: String) async throws -> String {
        let apiKey: String?
        do {
            apiKey = try apiKeyProvider()
        } catch {
            throw TranslationError.keychainFailure
        }

        guard let apiKey, !apiKey.isEmpty else {
            throw TranslationError.missingAPIKey
        }

        let request = try Self.makeRequest(text: text, apiKey: apiKey)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw Self.mapTransportError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslationError.invalidResponse
        }

        return try Self.parseResponse(data: data, statusCode: httpResponse.statusCode)
    }

    static func makeRequest(text: String, apiKey: String) throws -> URLRequest {
        let body = OpenRouterChatRequest(
            model: OpenRouterConfiguration.model,
            messages: [
                .init(role: "system", content: TranslationPrompt.system),
                .init(role: "user", content: text)
            ],
            reasoning: OpenRouterConfiguration.reasoningEffort.map {
                .init(effort: $0, exclude: true)
            }
        )

        var request = URLRequest(url: OpenRouterConfiguration.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = OpenRouterConfiguration.timeout
        request.setValue("Bearer " + apiKey, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(OpenRouterConfiguration.appTitle, forHTTPHeaderField: "X-Title")
        request.setValue(OpenRouterConfiguration.referer, forHTTPHeaderField: "HTTP-Referer")
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    static func parseResponse(data: Data, statusCode: Int) throws -> String {
        guard (200..<300).contains(statusCode) else {
            throw mapStatusCode(statusCode)
        }

        let decoded: OpenRouterChatResponse
        do {
            decoded = try JSONDecoder().decode(OpenRouterChatResponse.self, from: data)
        } catch {
            throw TranslationError.invalidResponse
        }

        if let errorCode = decoded.error?.code {
            throw mapStatusCode(errorCode)
        }

        guard
            let choices = decoded.choices,
            let message = choices.first?.message,
            let content = message.content
        else {
            throw TranslationError.invalidResponse
        }

        // Only trim accidental outer whitespace; internal line breaks are kept.
        let translation = content.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !translation.isEmpty else {
            throw TranslationError.emptyResponse
        }

        return translation
    }

    static func mapStatusCode(_ statusCode: Int) -> TranslationError {
        switch statusCode {
        case 401, 403:
            return .authenticationFailed
        case 402:
            return .insufficientCredits
        case 408:
            return .timedOut
        case 429:
            return .rateLimited
        default:
            return .serverError(statusCode: statusCode)
        }
    }

    static func mapTransportError(_ error: Error) -> TranslationError {
        guard let urlError = error as? URLError else {
            return .networkUnavailable
        }

        switch urlError.code {
        case .timedOut:
            return .timedOut
        default:
            return .networkUnavailable
        }
    }
}
