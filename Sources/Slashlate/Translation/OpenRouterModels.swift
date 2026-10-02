import Foundation

/// Only the parts of the OpenRouter chat completions API that Slashlate uses.
struct OpenRouterChatRequest: Encodable, Equatable {
    struct Message: Encodable, Equatable {
        let role: String
        let content: String
    }

    struct Reasoning: Encodable, Equatable {
        let effort: String
        let exclude: Bool
    }

    let model: String
    let messages: [Message]
    let reasoning: Reasoning?
}

struct OpenRouterChatResponse: Decodable {
    struct Choice: Decodable {
        let message: Message?
    }

    struct Message: Decodable {
        let content: String?
    }

    /// OpenRouter can report upstream failures inside a 200 response body.
    struct APIError: Decodable {
        let code: Int?
    }

    let choices: [Choice]?
    let error: APIError?
}
