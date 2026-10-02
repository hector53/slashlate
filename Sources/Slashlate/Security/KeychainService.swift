import Foundation
import Security

enum KeychainServiceError: LocalizedError {
    case unexpectedStatus(OSStatus)
    case invalidData

    var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status):
            return "Keychain error (" + String(status) + ")"
        case .invalidData:
            return "Keychain returned unreadable data"
        }
    }
}

/// Stores a single secret as a generic password in the user's login keychain.
struct KeychainService {
    let service: String
    let account: String

    static let openRouterAPIKey = KeychainService(
        service: "dev.hectoracosta.slashlate",
        account: "openrouter-api-key"
    )

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    /// Checks whether an item exists without reading the secret itself.
    var hasValue: Bool {
        var query = baseQuery
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }

    func read() throws -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw KeychainServiceError.unexpectedStatus(status)
        }

        guard let data = result as? Data, let value = String(data: data, encoding: .utf8) else {
            throw KeychainServiceError.invalidData
        }

        return value
    }

    /// Replaces the item instead of updating it, so the new item's access
    /// list trusts the currently signed app and macOS does not prompt on read.
    func save(_ value: String) throws {
        let deleteStatus = SecItemDelete(baseQuery as CFDictionary)

        guard deleteStatus == errSecSuccess || deleteStatus == errSecItemNotFound else {
            throw KeychainServiceError.unexpectedStatus(deleteStatus)
        }

        var addQuery = baseQuery
        addQuery[kSecValueData as String] = Data(value.utf8)
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
        addQuery[kSecAttrLabel as String] = "Slashlate OpenRouter API Key"

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)

        guard addStatus == errSecSuccess else {
            throw KeychainServiceError.unexpectedStatus(addStatus)
        }
    }
}

/// Reads the secret from Keychain at most once per launch, so a translation
/// never triggers a Keychain access prompt after the first one.
final class CachedKeychainValue {
    private let keychain: KeychainService
    private let lock = NSLock()
    private var cachedValue: String?

    init(keychain: KeychainService) {
        self.keychain = keychain
    }

    var hasValue: Bool {
        lock.withLock { cachedValue != nil } || keychain.hasValue
    }

    func read() throws -> String? {
        try lock.withLock {
            if let cachedValue {
                return cachedValue
            }

            let value = try keychain.read()
            cachedValue = value
            return value
        }
    }

    func save(_ value: String) throws {
        try lock.withLock {
            try keychain.save(value)
            cachedValue = value
        }
    }
}
