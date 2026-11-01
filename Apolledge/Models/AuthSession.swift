//
//  AuthSession.swift
//  Apolledge
//

import Foundation

struct AuthSession: Codable, Equatable {
    let userID: String
    let username: String
    let accessToken: String
    let refreshToken: String

    func replacingTokens(with tokens: AuthTokens) -> AuthSession {
        AuthSession(userID: userID, username: username, accessToken: tokens.accessToken, refreshToken: tokens.refreshToken ?? refreshToken)
    }
}

struct AuthTokens: Codable, Equatable {
    let accessToken: String
    /// Nil when the backend does not rotate refresh tokens: the current one stays valid.
    let refreshToken: String?
}
