//
//  SessionStore.swift
//  Apolledge
//

import Foundation
import Security

protocol SessionStore {
    func load() -> AuthSession?
    func save(_ session: AuthSession) throws
    func clear()
}

struct KeychainError: Error {
    let status: OSStatus
}

struct KeychainSessionStore: SessionStore {
    private let service: String
    private let account = "auth.session"

    init(service: String = Bundle.main.bundleIdentifier ?? "Apolledge") {
        self.service = service
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    func load() -> AuthSession? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data
        else { return nil }

        return try? JSONDecoder().decode(AuthSession.self, from: data)
    }

    func save(_ session: AuthSession) throws {
        let data = try JSONEncoder().encode(session)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]

        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            let addQuery = baseQuery.merging(attributes) { _, new in new }
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainError(status: addStatus) }
        default:
            throw KeychainError(status: updateStatus)
        }
    }

    func clear() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}

/// For previews and tests.
final class InMemorySessionStore: SessionStore {
    private var session: AuthSession?

    init(session: AuthSession? = nil) {
        self.session = session
    }

    func load() -> AuthSession? { session }
    func save(_ session: AuthSession) throws { self.session = session }
    func clear() { session = nil }
}
