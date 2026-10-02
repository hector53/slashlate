import Foundation

/// The boundary between Slashlate and any translation provider.
///
/// M1 ships a single OpenRouter implementation. Other providers can be added
/// later by conforming to this protocol without touching the Accessibility
/// or keyboard layers.
protocol TranslationService {
    func translate(_ text: String) async throws -> String
}

enum TranslationError: LocalizedError, Equatable {
    case missingAPIKey
    case keychainFailure
    case networkUnavailable
    case timedOut
    case authenticationFailed
    case insufficientCredits
    case rateLimited
    case serverError(statusCode: Int)
    case invalidResponse
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenRouter API key is not configured"
        case .keychainFailure:
            return "Could not read the OpenRouter API key from Keychain"
        case .networkUnavailable:
            return "Network unavailable - could not reach OpenRouter"
        case .timedOut:
            return "Translation request timed out"
        case .authenticationFailed:
            return "OpenRouter authentication failed - check your API key"
        case .insufficientCredits:
            return "OpenRouter account has insufficient credits"
        case .rateLimited:
            return "OpenRouter rate limit reached"
        case .serverError(let statusCode):
            return "OpenRouter request failed (HTTP " + String(statusCode) + ")"
        case .invalidResponse:
            return "OpenRouter returned an invalid response"
        case .emptyResponse:
            return "OpenRouter returned an empty translation"
        }
    }
}
