//
//  RemoteAuthService.swift
//  Apolledge
//

import Foundation

/// Backend-backed auth. `client` must not have a token provider: these endpoints are unauthenticated,
/// and routing refresh through an authenticating client would recurse on a 401.
struct RemoteAuthService: AuthService {
    let client: APIClient

    func signIn(username: String, password: String) async throws -> AuthSession {
        let endpoint = Endpoint<TokenResponse>(
            method: .post,
            path: "auth/local",
            body: SignInRequest(username: username, password: password),
            requiresAuth: false
        )

        do {
            return try await client.send(endpoint).session
        } catch APIError.unauthorized {
            throw AuthError.invalidCredentials
        } catch let error as APIError where error.isConnectivityIssue {
            throw AuthError.network
        }
    }

    func register(username: String, email: String, password: String) async throws -> AuthSession {
        let endpoint = Endpoint<TokenResponse>(
            method: .post,
            path: "auth/local/register",
            body: RegisterRequest(username: username, email: email, password: password),
            requiresAuth: false
        )

        do {
            return try await client.send(endpoint).session
        } catch APIError.server(let status, _, _) where status == 409 {
            throw AuthError.usernameTaken
        } catch let error as APIError where error.isConnectivityIssue {
            throw AuthError.network
        }
    }

    func signOut(accessToken: String) async throws {
        let endpoint = Endpoint<EmptyResponse>(
            method: .post,
            path: "auth/logout",
            headers: ["Authorization": "Bearer \(accessToken)"],
            requiresAuth: false
        )
        _ = try await client.send(endpoint)
    }

    func refresh(refreshToken: String) async throws -> AuthTokens {
        let endpoint = Endpoint<AuthTokens>(
            method: .post,
            path: "auth/refresh",
            body: RefreshRequest(refreshToken: refreshToken),
            requiresAuth: false
        )

        do {
            return try await client.send(endpoint)
        } catch APIError.server(let status, _, _) where status == 400 || status == 403 {
            throw APIError.unauthorized
        }
    }
}

private struct SignInRequest: Encodable {
    let username: String
    let password: String
}

private struct RegisterRequest: Encodable {
    let username: String
    let email: String
    let password: String
}

/// Login and register response. Mapped to `AuthSession`, whose flat shape is what the keychain already stores.
private struct TokenResponse: Decodable {
    struct User: Decodable {
        let id: String
        let username: String
    }

    let accessToken: String
    let refreshToken: String
    let user: User

    var session: AuthSession {
        AuthSession(userID: user.id, username: user.username, accessToken: accessToken, refreshToken: refreshToken)
    }
}

private struct RefreshRequest: Encodable {
    let refreshToken: String
}
