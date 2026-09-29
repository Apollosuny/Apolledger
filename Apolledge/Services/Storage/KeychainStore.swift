//
//  KeychainStore.swift
//  Apolledge
//

import Foundation
import Security

struct KeychainError: Error, Equatable {
    let status: OSStatus
}

/// Generic-password keychain wrapper scoped to one service. Use for secrets only; plain settings belong in `Preferences`.
struct KeychainStore {
    let service: String
    /// Device-only and readable after first unlock, so background refreshes work but items never sync or restore to another device.
    var accessibility: CFString = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

    init(service: String = Bundle.main.bundleIdentifier ?? "Apolledge") {
        self.service = service
    }

    func data(forKey key: String) throws -> Data? {
        var query = baseQuery(forKey: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            return item as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError(status: status)
        }
    }

    func set(_ data: Data, forKey key: String) throws {
        let query = baseQuery(forKey: key)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: accessibility,
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            let addStatus = SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainError(status: addStatus) }
        default:
            throw KeychainError(status: updateStatus)
        }
    }

    func removeValue(forKey key: String) throws {
        let status = SecItemDelete(baseQuery(forKey: key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(status: status)
        }
    }

    func value<Value: Decodable>(_ type: Value.Type, forKey key: String) throws -> Value? {
        try data(forKey: key).map { try JSONDecoder().decode(type, from: $0) }
    }

    func set<Value: Encodable>(_ value: Value, forKey key: String) throws {
        try set(JSONEncoder().encode(value), forKey: key)
    }

    private func baseQuery(forKey key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
    }
}
