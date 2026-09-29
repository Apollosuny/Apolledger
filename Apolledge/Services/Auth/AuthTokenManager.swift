//
//  AuthTokenManager.swift
//  Apolledge
//

import Foundation

/// Single owner of the persisted session: caches it in memory, persists changes, and refreshes tokens for `APIClient`.
final class AuthTokenManager: AccessTokenProvider {
    private let store: SessionStore
    private let authService: AuthService
    private var inFlightRefresh: Task<String, Error>?

    private(set) var session: AuthSession?
    /// Called when the refresh token is rejected and the session has been cleared.
    var onSessionExpired: (() -> Void)?

    init(store: SessionStore, authService: AuthService) {
        self.store = store
        self.authService = authService
        self.session = store.load()
    }

    var accessToken: String? { session?.accessToken }

    func update(_ session: AuthSession) throws {
        try store.save(session)
        self.session = session
    }

    func clear() {
        inFlightRefresh?.cancel()
        inFlightRefresh = nil
        store.clear()
        session = nil
    }

    func refreshAccessToken(rejecting rejectedToken: String) async throws -> String {
        // Another request already refreshed while this one was in flight.
        if let current = session?.accessToken, current != rejectedToken {
            return current
        }
        if let inFlightRefresh {
            return try await inFlightRefresh.value
        }
        guard let refreshToken = session?.refreshToken else {
            throw APIError.unauthorized
        }

        // Unstructured on purpose: cancelling the request that triggered the refresh must not abort it for the others waiting.
        let task = Task { () throws -> String in
            defer { inFlightRefresh = nil }
            do {
                let tokens = try await authService.refresh(refreshToken: refreshToken)
                // Signed out (or re-signed in) while refreshing: do not resurrect the old session.
                guard let current = session, current.refreshToken == refreshToken else {
                    throw APIError.unauthorized
                }
                let renewed = current.replacingTokens(with: tokens)
                // A keychain write failure should not fail the request; the in-memory token is still valid for this launch.
                try? store.save(renewed)
                session = renewed
                return renewed.accessToken
            } catch APIError.unauthorized {
                expireSession(ifRefreshTokenIs: refreshToken)
                throw APIError.unauthorized
            }
        }
        inFlightRefresh = task
        return try await task.value
    }

    private func expireSession(ifRefreshTokenIs refreshToken: String) {
        guard session?.refreshToken == refreshToken else { return }
        store.clear()
        session = nil
        onSessionExpired?()
    }
}
