//
//  SessionStore.swift
//  Apolledge
//

import Foundation

protocol SessionStore {
    func load() -> AuthSession?
    func save(_ session: AuthSession) throws
    func clear()
}

struct KeychainSessionStore: SessionStore {
    private let keychain: KeychainStore
    private let key = "auth.session"

    init(keychain: KeychainStore = KeychainStore()) {
        self.keychain = keychain
    }

    /// An unreadable or outdated payload is treated as signed out rather than surfaced as an error.
    func load() -> AuthSession? {
        try? keychain.value(AuthSession.self, forKey: key)
    }

    func save(_ session: AuthSession) throws {
        try keychain.set(session, forKey: key)
    }

    func clear() {
        try? keychain.removeValue(forKey: key)
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
