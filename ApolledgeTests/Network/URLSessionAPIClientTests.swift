//
//  URLSessionAPIClientTests.swift
//  ApolledgeTests
//

import Foundation
import Testing
@testable import Apolledge

@MainActor
struct URLSessionAPIClientTests {
    private struct Profile: Codable, Equatable {
        let name: String
    }

    private let baseURL = URL(string: "https://example.test/v1")!
    private let profileEndpoint = Endpoint<Profile>(method: .get, path: "me")

    private func makeClient(
        transport: StubTransport,
        session: AuthSession? = .fixture(accessToken: "old", refreshToken: "r1"),
        authService: StubAuthService? = nil
    ) -> (URLSessionAPIClient, AuthTokenManager) {
        let tokenManager = AuthTokenManager(
            store: InMemorySessionStore(session: session),
            authService: authService ?? StubAuthService()
        )
        let client = URLSessionAPIClient(baseURL: baseURL, transport: transport, tokenProvider: tokenManager)
        return (client, tokenManager)
    }

    @Test func decodesSuccessAndSendsBearerToken() async throws {
        let transport = StubTransport { _ in (200, #"{"name":"Minh"}"#) }
        let (client, _) = makeClient(transport: transport)

        let profile = try await client.send(profileEndpoint)

        #expect(profile == Profile(name: "Minh"))
        #expect(transport.requests.first?.url?.absoluteString == "https://example.test/v1/me")
        #expect(transport.requests.first?.value(forHTTPHeaderField: "Authorization") == "Bearer old")
    }

    @Test func mapsServerErrorBody() async throws {
        let transport = StubTransport { _ in (422, #"{"code":"invalid_amount","message":"Số tiền không hợp lệ"}"#) }
        let (client, _) = makeClient(transport: transport)

        await #expect(throws: APIError.server(status: 422, code: "invalid_amount", message: "Số tiền không hợp lệ")) {
            try await client.send(profileEndpoint)
        }
    }

    @Test func refreshesOnceOn401AndRetries() async throws {
        let authService = StubAuthService()
        let transport = StubTransport { request in
            request.value(forHTTPHeaderField: "Authorization") == "Bearer new" ? (200, #"{"name":"Minh"}"#) : (401, "")
        }
        let (client, tokenManager) = makeClient(transport: transport, authService: authService)

        let profile = try await client.send(profileEndpoint)

        #expect(profile == Profile(name: "Minh"))
        #expect(authService.refreshCount == 1)
        #expect(tokenManager.session?.accessToken == "new")
        #expect(tokenManager.session?.refreshToken == "r2")
    }

    @Test func concurrent401sShareOneRefresh() async throws {
        let authService = StubAuthService(delay: .milliseconds(50))
        let transport = StubTransport { request in
            request.value(forHTTPHeaderField: "Authorization") == "Bearer new" ? (200, #"{"name":"Minh"}"#) : (401, "")
        }
        let (client, _) = makeClient(transport: transport, authService: authService)

        async let first = client.send(profileEndpoint)
        async let second = client.send(profileEndpoint)
        async let third = client.send(profileEndpoint)
        let profiles = try await [first, second, third]

        #expect(profiles.count == 3)
        #expect(authService.refreshCount == 1)
    }

    @Test func rejectedRefreshExpiresSession() async throws {
        let authService = StubAuthService(result: .failure(APIError.unauthorized))
        let transport = StubTransport { _ in (401, "") }
        let (client, tokenManager) = makeClient(transport: transport, authService: authService)
        var expired = false
        tokenManager.onSessionExpired = { expired = true }

        await #expect(throws: APIError.unauthorized) {
            try await client.send(profileEndpoint)
        }
        #expect(expired)
        #expect(tokenManager.session == nil)
    }

    @Test func offlineRefreshKeepsSession() async throws {
        let authService = StubAuthService(result: .failure(APIError.offline))
        let transport = StubTransport { _ in (401, "") }
        let (client, tokenManager) = makeClient(transport: transport, authService: authService)

        await #expect(throws: APIError.offline) {
            try await client.send(profileEndpoint)
        }
        #expect(tokenManager.session != nil)
    }

    @Test func unauthenticatedEndpointSkipsTokenAndRefresh() async throws {
        let authService = StubAuthService()
        let transport = StubTransport { _ in (401, "") }
        let (client, _) = makeClient(transport: transport, authService: authService)
        let login = Endpoint<Profile>(method: .post, path: "auth/login", body: ["username": "minh"], requiresAuth: false)

        await #expect(throws: APIError.unauthorized) {
            try await client.send(login)
        }
        #expect(transport.requests.first?.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(transport.requests.first?.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(authService.refreshCount == 0)
    }

    @Test func emptyBodyDecodesAsEmptyResponse() async throws {
        let transport = StubTransport { _ in (204, "") }
        let (client, _) = makeClient(transport: transport)

        let response = try await client.send(Endpoint<EmptyResponse>(method: .delete, path: "transactions/1"))

        #expect(response == EmptyResponse())
    }

    @Test func mapsOfflineURLError() async throws {
        let transport = StubTransport { _ in throw URLError(.notConnectedToInternet) }
        let (client, _) = makeClient(transport: transport)

        await #expect(throws: APIError.offline) {
            try await client.send(profileEndpoint)
        }
    }
}
