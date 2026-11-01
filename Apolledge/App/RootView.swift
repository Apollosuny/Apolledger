//
//  RootView.swift
//  Apolledge
//
//  Created by Trung Trần on 1/9/26.
//

import SwiftUI

struct RootView: View {
    @Environment(AppSession.self) private var session
    @State private var showsRegister = false

    var body: some View {
        ZStack {
            switch session.phase {
            case .launching:
                SplashView()
                    .transition(.opacity)
            case .signedOut:
                if showsRegister {
                    RegisterView(onShowLogin: { showsRegister = false })
                        .transition(.opacity)
                } else {
                    LoginView(onRegister: { showsRegister = true })
                        .transition(.opacity)
                }
            case .signedIn(let authSession):
                MainTabView(username: authSession.username, onSignOut: session.signOut)
                    .transition(.opacity)
            }
        }
        .animation(AppMotion.standard, value: session.phase)
        .animation(AppMotion.standard, value: showsRegister)
        .onChange(of: session.phase) { _, phase in
            if case .signedIn = phase { showsRegister = false }
        }
        .task { await session.restore() }
    }
}

#Preview("Signed out") {
    RootView()
        .environment(AppContainer.preview().session)
}
