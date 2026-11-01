//
//  ApolledgeApp.swift
//  Apolledge
//
//  Created by Trung Trần on 1/9/26.
//

import SwiftData
import SwiftUI

@main
struct ApolledgeApp: App {
    @State private var container = AppContainer.live()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(container.session)
                .environment(\.ledgerService, container.ledgerService)
                .modelContainer(container.modelContainer)
        }
    }
}
