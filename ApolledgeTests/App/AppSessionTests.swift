//
//  AppSessionTests.swift
//  ApolledgeTests
//

import Foundation
import Testing
@testable import Apolledge

@MainActor
struct AppSessionTests {
    private struct SaveFailure: Error, Equatable {}

    private final class FailingSaveSessionStore: SessionStore {
        func load() -> AuthSession? { nil }
        func save(_ session: AuthSession) throws { throw SaveFailure() }
        func clear() {}
    }

    private let stored = AuthSession.fixture(accessToken: "old", refreshToken: "r1")

    private func makeSession(
        store: (any SessionStore)? = nil,
        authService: StubAuthService? = nil
    ) -> (session: AppSession, tokenManager: AuthTokenManager, store: any SessionStore) {
        let store = store ?? InMemorySessionStore()
        let authService = authService ?? StubAuthService()
        let tokenManager = AuthTokenManager(store: store, authService: authService)
        let session = AppSession(authService: authService, tokenManager: tokenManager, minimumSplashDuration: .zero)
        return (session, tokenManager, store)
    }

    // MARK: - restore

    @Test func startsInLaunchingPhase() {
        let (session, _, _) = makeSession()

        #expect(session.phase == .launching)
    }

    @Test func restoreWithStoredSessionSignsIn() async {
        let (session, _, _) = makeSession(store: InMemorySessionStore(session: stored))

        await session.restore()

        #expect(session.phase == .signedIn(stored))
    }

    @Test func restoreWithoutStoredSessionSignsOut() async {
        let (session, _, _) = makeSession()

        await session.restore()

        #expect(session.phase == .signedOut)
    }

    @Test func restoreIsIgnoredOnceLaunchingIsOver() async throws {
        let (session, _, _) = makeSession()
        try await session.signIn(username: "minh", password: "secret1")

        await session.restore()

        #expect(session.phase == .signedIn(stored))
    }

    // MARK: - signIn

    @Test func signInPersistsAndPublishesSession() async throws {
        let (session, tokenManager, store) = makeSession()
        await session.restore()

        try await session.signIn(username: "minh", password: "secret1")

        #expect(session.phase == .signedIn(stored))
        #expect(store.load() == stored)
        #expect(tokenManager.session == stored)
    }

    @Test func signInFailureLeavesStateUntouched() async {
        let authService = StubAuthService(signInResult: .failure(AuthError.invalidCredentials))
        let (session, tokenManager, store) = makeSession(authService: authService)
        await session.restore()

        await #expect(throws: AuthError.invalidCredentials) {
            try await session.signIn(username: "minh", password: "wrong")
        }

        #expect(session.phase == .signedOut)
        #expect(store.load() == nil)
        #expect(tokenManager.session == nil)
    }

    @Test func signInDoesNotPublishSessionThatFailedToPersist() async {
        let (session, tokenManager, _) = makeSession(store: FailingSaveSessionStore())
        await session.restore()

        await #expect(throws: SaveFailure()) {
            try await session.signIn(username: "minh", password: "secret1")
        }

        #expect(session.phase == .signedOut)
        #expect(tokenManager.session == nil)
    }

    // MARK: - signOut

    @Test func signOutClearsStoredSession() async {
        let (session, tokenManager, store) = makeSession(store: InMemorySessionStore(session: stored))
        await session.restore()

        session.signOut()

        #expect(session.phase == .signedOut)
        #expect(store.load() == nil)
        #expect(tokenManager.session == nil)
    }

    // MARK: - session expiry

    @Test func rejectedRefreshTokenSignsOut() async {
        let authService = StubAuthService(result: .failure(APIError.unauthorized))
        let (session, tokenManager, store) = makeSession(store: InMemorySessionStore(session: stored), authService: authService)
        await session.restore()

        _ = try? await tokenManager.refreshAccessToken(rejecting: "old")

        #expect(session.phase == .signedOut)
        #expect(store.load() == nil)
    }

    @Test func offlineRefreshKeepsUserSignedIn() async {
        let authService = StubAuthService(result: .failure(APIError.offline))
        let (session, tokenManager, store) = makeSession(store: InMemorySessionStore(session: stored), authService: authService)
        await session.restore()

        _ = try? await tokenManager.refreshAccessToken(rejecting: "old")

        #expect(session.phase == .signedIn(stored))
        #expect(store.load() == stored)
    }
}
