//
//  MockAuthService.swift
//  Apolledge
//

import Foundation

/// Used by SwiftUI previews: accepts any username with a password of at least 6 characters.
struct MockAuthService: AuthService {
    var latency: Duration = .milliseconds(800)

    func signIn(username: String, password: String) async throws -> AuthSession {
        try await Task.sleep(for: latency)

        guard password.count >= 6 else {
            throw AuthError.invalidCredentials
        }

        return AuthSession(
            userID: UUID().uuidString,
            username: username,
            accessToken: UUID().uuidString,
            refreshToken: UUID().uuidString
        )
    }

    func register(username: String, email: String, password: String) async throws -> AuthSession {
        try await signIn(username: username, password: password)
    }

    func signOut(accessToken: String) async throws {}

    func refresh(refreshToken: String) async throws -> AuthTokens {
        try await Task.sleep(for: latency)
        return AuthTokens(accessToken: UUID().uuidString, refreshToken: UUID().uuidString)
    }
}
