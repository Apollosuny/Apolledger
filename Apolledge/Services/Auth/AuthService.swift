//
//  AuthService.swift
//  Apolledge
//

import Foundation

protocol AuthService {
    func signIn(username: String, password: String) async throws -> AuthSession
    /// Must throw `APIError.unauthorized` when the refresh token itself is rejected, so the session can be ended.
    func refresh(refreshToken: String) async throws -> AuthTokens
}

enum AuthError: LocalizedError, Equatable {
    case invalidCredentials
    case network

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            "Tên đăng nhập hoặc mật khẩu không đúng."
        case .network:
            "Không kết nối được. Kiểm tra mạng rồi thử lại."
        }
    }
}
