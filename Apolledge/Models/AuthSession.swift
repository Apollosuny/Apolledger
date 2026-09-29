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
        AuthSession(userID: userID, username: username, accessToken: tokens.accessToken, refreshToken: tokens.refreshToken)
    }
}

struct AuthTokens: Codable, Equatable {
    let accessToken: String
    let refreshToken: String
}
