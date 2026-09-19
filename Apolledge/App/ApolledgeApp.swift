//
//  ApolledgeApp.swift
//  Apolledge
//
//  Created by Trung Trần on 1/9/26.
//

import SwiftUI

@main
struct ApolledgeApp: App {
    @State private var session = AppSession(
        authService: MockAuthService(),
        sessionStore: KeychainSessionStore()
    )

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
        }
    }
}
