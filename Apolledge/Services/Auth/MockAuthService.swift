//
//  MockAuthService.swift
//  Apolledge
//

import Foundation

/// Stand-in until a real backend exists: accepts any username with a password of at least 6 characters.
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
            accessToken: UUID().uuidString
        )
    }
}
