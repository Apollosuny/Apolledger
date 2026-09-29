//
//  RootView.swift
//  Apolledge
//
//  Created by Trung Trần on 1/9/26.
//

import SwiftUI

struct RootView: View {
    @Environment(AppSession.self) private var session

    var body: some View {
        ZStack {
            switch session.phase {
            case .launching:
                SplashView()
                    .transition(.opacity)
            case .signedOut:
                LoginView()
                    .transition(.opacity)
            case .signedIn(let authSession):
                LedgerView(username: authSession.username, onSignOut: session.signOut)
                    .transition(.opacity)
            }
        }
        .animation(AppMotion.standard, value: session.phase)
        .task { await session.restore() }
    }
}

#Preview("Signed out") {
    RootView()
        .environment(AppContainer.preview().session)
}
