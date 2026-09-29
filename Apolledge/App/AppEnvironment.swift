//
//  AppEnvironment.swift
//  Apolledge
//

import Foundation

/// Per-build configuration. Debug builds talk to development, Release builds to production.
struct AppEnvironment {
    let name: String
    let apiBaseURL: URL

    static let development = AppEnvironment(
        name: "development",
        apiBaseURL: URL(string: "https://api-dev.apolledge.app/v1")!
    )

    static let production = AppEnvironment(
        name: "production",
        apiBaseURL: URL(string: "https://api.apolledge.app/v1")!
    )

    static var current: AppEnvironment {
        #if DEBUG
        .development
        #else
        .production
        #endif
    }
}
