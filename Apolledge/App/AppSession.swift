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
        /// Tokens inside may be stale after a refresh; `AuthTokenManager` holds the current ones.
        case signedIn(AuthSession)
    }

    private(set) var phase: Phase = .launching

    private let authService: AuthService
    private let tokenManager: AuthTokenManager
    private let minimumSplashDuration: Duration

    init(
        authService: AuthService,
        tokenManager: AuthTokenManager,
        minimumSplashDuration: Duration = .seconds(1)
    ) {
        self.authService = authService
        self.tokenManager = tokenManager
        self.minimumSplashDuration = minimumSplashDuration

        tokenManager.onSessionExpired = { [weak self] in
            self?.phase = .signedOut
        }
    }

    func restore() async {
        guard phase == .launching else { return }

        let storedSession = tokenManager.session
        // Keeps the splash from flashing for a single frame when restore is instant.
        try? await Task.sleep(for: minimumSplashDuration)

        phase = storedSession.map(Phase.signedIn) ?? .signedOut
    }

    func signIn(username: String, password: String) async throws {
        let session = try await authService.signIn(username: username, password: password)
        try tokenManager.update(session)
        phase = .signedIn(session)
    }

    func signOut() {
        tokenManager.clear()
        phase = .signedOut
    }
}
