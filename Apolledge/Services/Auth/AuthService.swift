//
//  AuthService.swift
//  Apolledge
//

import Foundation

protocol AuthService {
    func signIn(username: String, password: String) async throws -> AuthSession
    func register(username: String, email: String, password: String) async throws -> AuthSession
    /// Revokes the user's refresh tokens on the server. Takes the token explicitly because the local session is cleared first.
    func signOut(accessToken: String) async throws
    /// Must throw `APIError.unauthorized` when the refresh token itself is rejected, so the session can be ended.
    func refresh(refreshToken: String) async throws -> AuthTokens
}

enum AuthError: LocalizedError, Equatable {
    case invalidCredentials
    case network
    case usernameTaken

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            "Tên đăng nhập hoặc mật khẩu không đúng."
        case .network:
            "Không kết nối được. Kiểm tra mạng rồi thử lại."
        case .usernameTaken:
            "Tên đăng nhập này đã có người dùng."
        }
    }
}
