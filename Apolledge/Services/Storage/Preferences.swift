//
//  Preferences.swift
//  Apolledge
//

import Foundation

/// Typed UserDefaults key. Declare keys as static members so names and defaults live in one place:
///
///     extension PreferenceKey where Value == Bool {
///         static let hidesBalance = PreferenceKey("hidesBalance", default: false)
///     }
struct PreferenceKey<Value: Codable> {
    let name: String
    let defaultValue: Value

    init(_ name: String, default defaultValue: Value) {
        self.name = name
        self.defaultValue = defaultValue
    }
}

/// Non-sensitive settings only — UserDefaults is unencrypted and included in backups.
/// Property-list types are stored natively (so `@AppStorage` can read the same key); other `Codable` values are stored as JSON.
final class Preferences {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    subscript<Value>(key: PreferenceKey<Value>) -> Value {
        get {
            guard let stored = defaults.object(forKey: key.name) else { return key.defaultValue }
            if let value = stored as? Value {
                return value
            }
            if let data = stored as? Data, let value = try? JSONDecoder().decode(Value.self, from: data) {
                return value
            }
            return key.defaultValue
        }
        set {
            if let optional = newValue as? AnyOptional, optional.isNil {
                defaults.removeObject(forKey: key.name)
            } else if Self.isPropertyListValue(newValue) {
                defaults.set(newValue, forKey: key.name)
            } else if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: key.name)
            }
        }
    }

    func removeValue<Value>(for key: PreferenceKey<Value>) {
        defaults.removeObject(forKey: key.name)
    }

    private static func isPropertyListValue(_ value: Any) -> Bool {
        let unwrapped = (value as? AnyOptional)?.wrapped ?? value
        switch unwrapped {
        case is String, is Bool, is Int, is Double, is Float, is Date, is Data:
            return true
        default:
            return false
        }
    }
}

private protocol AnyOptional {
    var isNil: Bool { get }
    var wrapped: Any? { get }
}

extension Optional: AnyOptional {
    fileprivate var isNil: Bool { self == nil }
    fileprivate var wrapped: Any? { self.map { $0 as Any } }
}
