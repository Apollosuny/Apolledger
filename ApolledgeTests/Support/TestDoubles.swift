//
//  TestDoubles.swift
//  ApolledgeTests
//

import Foundation
@testable import Apolledge

@MainActor
final class StubTransport: HTTPTransport {
    private let handler: (URLRequest) throws -> (Int, String)
    private(set) var requests: [URLRequest] = []

    init(handler: @escaping (URLRequest) throws -> (Int, String)) {
        self.handler = handler
    }

    func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        let (status, body) = try handler(request)
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        return (Data(body.utf8), response)
    }
}

@MainActor
final class StubAuthService: AuthService {
    private let delay: Duration
    private let signInResult: Result<AuthSession, Error>
    private let result: Result<AuthTokens, Error>
    private(set) var refreshCount = 0
    private(set) var signInCount = 0

    init(
        delay: Duration = .zero,
        signInResult: Result<AuthSession, Error> = .success(.fixture(accessToken: "old", refreshToken: "r1")),
        result: Result<AuthTokens, Error> = .success(AuthTokens(accessToken: "new", refreshToken: "r2"))
    ) {
        self.delay = delay
        self.signInResult = signInResult
        self.result = result
    }

    func signIn(username: String, password: String) async throws -> AuthSession {
        signInCount += 1
        return try signInResult.get()
    }

    func refresh(refreshToken: String) async throws -> AuthTokens {
        refreshCount += 1
        try await Task.sleep(for: delay)
        return try result.get()
    }
}

extension AuthSession {
    static func fixture(accessToken: String, refreshToken: String) -> AuthSession {
        AuthSession(userID: "u1", username: "minh", accessToken: accessToken, refreshToken: refreshToken)
    }
}
