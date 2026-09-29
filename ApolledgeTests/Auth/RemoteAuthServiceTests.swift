//
//  RemoteAuthServiceTests.swift
//  ApolledgeTests
//

import Foundation
import Testing
@testable import Apolledge

/// Runs `RemoteAuthService` through the real `URLSessionAPIClient` so the wire format and error mapping are covered together.
@MainActor
struct RemoteAuthServiceTests {
    private let baseURL = URL(string: "https://example.test/v1")!
    private let sessionJSON = #"{"userID":"u1","username":"minh","accessToken":"a1","refreshToken":"r1"}"#
    private let tokensJSON = #"{"accessToken":"a2","refreshToken":"r2"}"#

    private func makeService(_ transport: StubTransport) -> RemoteAuthService {
        RemoteAuthService(client: URLSessionAPIClient(baseURL: baseURL, transport: transport))
    }

    private func jsonBody(of request: URLRequest?) throws -> [String: String] {
        let data = try #require(request?.httpBody)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: String])
    }

    // MARK: - signIn

    @Test func signInPostsCredentialsWithoutBearerToken() async throws {
        let transport = StubTransport { _ in (200, sessionJSON) }

        let session = try await makeService(transport).signIn(username: "minh", password: "secret1")

        let request = try #require(transport.requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://example.test/v1/auth/login")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(try jsonBody(of: request) == ["username": "minh", "password": "secret1"])
        #expect(session == AuthSession(userID: "u1", username: "minh", accessToken: "a1", refreshToken: "r1"))
    }

    @Test func signInMapsUnauthorizedToInvalidCredentials() async {
        let transport = StubTransport { _ in (401, "") }

        await #expect(throws: AuthError.invalidCredentials) {
            try await makeService(transport).signIn(username: "minh", password: "wrong")
        }
    }

    @Test(arguments: [URLError.Code.notConnectedToInternet, .timedOut, .cannotFindHost])
    func signInMapsConnectivityFailuresToNetworkError(code: URLError.Code) async {
        let transport = StubTransport { _ in throw URLError(code) }

        await #expect(throws: AuthError.network) {
            try await makeService(transport).signIn(username: "minh", password: "secret1")
        }
    }

    @Test func signInPassesServerErrorsThrough() async {
        let transport = StubTransport { _ in (500, #"{"code":"internal","message":"boom"}"#) }

        await #expect(throws: APIError.server(status: 500, code: "internal", message: "boom")) {
            try await makeService(transport).signIn(username: "minh", password: "secret1")
        }
    }

    @Test func signInRejectsResponseWithoutRefreshToken() async {
        let transport = StubTransport { _ in (200, #"{"userID":"u1","username":"minh","accessToken":"a1"}"#) }

        await #expect {
            try await makeService(transport).signIn(username: "minh", password: "secret1")
        } throws: { error in
            guard case APIError.decoding = error else { return false }
            return true
        }
    }

    // MARK: - refresh

    @Test func refreshPostsRefreshTokenWithoutBearerToken() async throws {
        let transport = StubTransport { _ in (200, tokensJSON) }

        let tokens = try await makeService(transport).refresh(refreshToken: "r1")

        let request = try #require(transport.requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://example.test/v1/auth/refresh")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(try jsonBody(of: request) == ["refreshToken": "r1"])
        #expect(tokens == AuthTokens(accessToken: "a2", refreshToken: "r2"))
    }

    @Test(arguments: [400, 401, 403])
    func refreshReportsRejectedTokenAsUnauthorized(status: Int) async {
        let transport = StubTransport { _ in (status, "") }

        await #expect(throws: APIError.unauthorized) {
            try await makeService(transport).refresh(refreshToken: "r1")
        }
    }

    @Test func refreshDoesNotTreatServerFailureAsRejectedToken() async {
        let transport = StubTransport { _ in (500, "") }

        await #expect(throws: APIError.server(status: 500, code: nil, message: nil)) {
            try await makeService(transport).refresh(refreshToken: "r1")
        }
    }

    @Test func refreshDoesNotTreatOfflineAsRejectedToken() async {
        let transport = StubTransport { _ in throw URLError(.notConnectedToInternet) }

        await #expect(throws: APIError.offline) {
            try await makeService(transport).refresh(refreshToken: "r1")
        }
    }
}
