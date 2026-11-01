//
//  AppEnvironment.swift
//  Apolledge
//

import Foundation

/// Per-build configuration. Debug builds talk to a backend on this Mac (simulator only), Release builds to production.
struct AppEnvironment {
    let name: String
    let apiBaseURL: URL

    static let development = AppEnvironment(
        name: "development",
        apiBaseURL: URL(string: "http://localhost:8080/api/v1")!
    )

    static let production = AppEnvironment(
        name: "production",
        apiBaseURL: URL(string: "https://api.apolledge.app/api/v1")!
    )

    static var current: AppEnvironment {
        #if DEBUG
        .development
        #else
        .production
        #endif
    }
}
