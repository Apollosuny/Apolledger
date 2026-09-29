//
//  StorageTests.swift
//  ApolledgeTests
//

import Foundation
import SwiftData
import Testing
@testable import Apolledge

@MainActor
struct PreferencesTests {
    private struct Filter: Codable, Equatable {
        let categories: [String]
    }

    private let suiteName = "PreferencesTests.\(UUID().uuidString)"

    @Test func storesPrimitivesNativelyAndCodableAsJSON() throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = Preferences(defaults: defaults)
        let hidesBalance = PreferenceKey("hidesBalance", default: false)
        let filter = PreferenceKey("filter", default: Filter(categories: []))

        #expect(preferences[hidesBalance] == false)

        preferences[hidesBalance] = true
        preferences[filter] = Filter(categories: ["food"])

        #expect(preferences[hidesBalance] == true)
        #expect(defaults.bool(forKey: "hidesBalance"))
        #expect(preferences[filter] == Filter(categories: ["food"]))
    }

    @Test func settingNilRemovesOptionalValue() throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = Preferences(defaults: defaults)
        let lastWallet = PreferenceKey<String?>("lastWallet", default: nil)

        preferences[lastWallet] = "cash"
        #expect(preferences[lastWallet] == "cash")

        preferences[lastWallet] = nil
        #expect(preferences[lastWallet] == nil)
        #expect(defaults.object(forKey: "lastWallet") == nil)
    }
}

@MainActor
struct KeychainStoreTests {
    @Test func roundTripsAndRemovesCodableValue() throws {
        let keychain = KeychainStore(service: "KeychainStoreTests.\(UUID().uuidString)")
        let key = "session"
        defer { try? keychain.removeValue(forKey: key) }
        let session = AuthSession.fixture(accessToken: "a", refreshToken: "r")

        #expect(try keychain.value(AuthSession.self, forKey: key) == nil)

        try keychain.set(session, forKey: key)
        try keychain.set(session.replacingTokens(with: AuthTokens(accessToken: "b", refreshToken: "r2")), forKey: key)
        #expect(try keychain.value(AuthSession.self, forKey: key)?.accessToken == "b")

        try keychain.removeValue(forKey: key)
        #expect(try keychain.value(AuthSession.self, forKey: key) == nil)
    }
}

@MainActor
struct PersistenceControllerTests {
    @Test func buildsInMemoryContainer() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        #expect(container.configurations.first?.isStoredInMemoryOnly == true)
    }
}
