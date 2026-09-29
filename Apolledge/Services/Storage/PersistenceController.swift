//
//  PersistenceController.swift
//  Apolledge
//

import Foundation
import SwiftData

/// Builds the app's SwiftData container. Register each `@Model` type in `models` as features add them.
enum PersistenceController {
    static let models: [any PersistentModel.Type] = []

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
