//
//  AppContainer.swift
//  Apolledge
//

import Foundation
import SwiftData

/// Composition root: builds the shared infrastructure once and hands it to features.
final class AppContainer {
    let environment: AppEnvironment
    let apiClient: APIClient
    let preferences: Preferences
    let modelContainer: ModelContainer
    let session: AppSession
    let ledgerService: LedgerService

    private init(
        environment: AppEnvironment,
        authService: AuthService,
        ledgerService: ((APIClient) -> LedgerService)? = nil,
        sessionStore: SessionStore,
        preferences: Preferences,
        modelContainer: ModelContainer
    ) {
        let tokenManager = AuthTokenManager(store: sessionStore, authService: authService)
        let apiClient = URLSessionAPIClient(baseURL: environment.apiBaseURL, tokenProvider: tokenManager)

        self.environment = environment
        self.apiClient = apiClient
        self.ledgerService = ledgerService?(apiClient) ?? MockLedgerService()
        self.preferences = preferences
        self.modelContainer = modelContainer
        self.session = AppSession(authService: authService, tokenManager: tokenManager)
    }

    static func live() -> AppContainer {
        let environment = AppEnvironment.current

        let modelContainer: ModelContainer
        do {
            modelContainer = try PersistenceController.makeContainer()
        } catch {
            // Do not delete the store to recover: it may hold the user's only copy of their records.
            fatalError("Failed to open SwiftData store: \(error)")
        }

        return AppContainer(
            environment: environment,
            // Needs its own token-less client so a refresh never re-enters the token provider.
            authService: RemoteAuthService(client: URLSessionAPIClient(baseURL: environment.apiBaseURL)),
            ledgerService: { RemoteLedgerService(client: $0) },
            sessionStore: KeychainSessionStore(),
            preferences: Preferences(),
            modelContainer: modelContainer
        )
    }

    static func preview(session: AuthSession? = nil) -> AppContainer {
        AppContainer(
            environment: .development,
            authService: MockAuthService(),
            sessionStore: InMemorySessionStore(session: session),
            preferences: Preferences(defaults: UserDefaults(suiteName: "preview") ?? .standard),
            modelContainer: try! PersistenceController.makeContainer(inMemory: true)
        )
    }
}
