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
        let endpoint = Endpoint<AuthSession>(
            method: .post,
            path: "auth/login",
            body: SignInRequest(username: username, password: password),
            requiresAuth: false
        )

        do {
            return try await client.send(endpoint)
        } catch APIError.unauthorized {
            throw AuthError.invalidCredentials
        } catch let error as APIError where error.isConnectivityIssue {
            throw AuthError.network
        }
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

private struct RefreshRequest: Encodable {
    let refreshToken: String
}
