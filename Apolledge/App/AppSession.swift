//
//  AppSession.swift
//  Apolledge
//

import Foundation
import Observation

/// Owns the authentication lifecycle and decides which top-level screen is shown.
@Observable
final class AppSession {
    enum Phase: Equatable {
        case launching
        case signedOut
        case signedIn(AuthSession)
    }

    private(set) var phase: Phase = .launching

    private let authService: AuthService
    private let sessionStore: SessionStore
    private let minimumSplashDuration: Duration

    init(
        authService: AuthService,
        sessionStore: SessionStore,
        minimumSplashDuration: Duration = .seconds(1)
    ) {
        self.authService = authService
        self.sessionStore = sessionStore
        self.minimumSplashDuration = minimumSplashDuration
    }

    func restore() async {
        guard phase == .launching else { return }

        let storedSession = sessionStore.load()
        // Keeps the splash from flashing for a single frame when restore is instant.
        try? await Task.sleep(for: minimumSplashDuration)

        phase = storedSession.map(Phase.signedIn) ?? .signedOut
    }

    func signIn(username: String, password: String) async throws {
        let session = try await authService.signIn(username: username, password: password)
        try sessionStore.save(session)
        phase = .signedIn(session)
    }

    func signOut() {
        sessionStore.clear()
        phase = .signedOut
    }
}
