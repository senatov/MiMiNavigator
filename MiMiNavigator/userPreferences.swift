//
//  UserPreferences.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 27.09.24.
//

import Foundation
import SwiftUI

enum MyTestEnum: String {
    case a
    case b
    case c
}

enum MyIntEnum: Int {
    case a  = 1
    case b
    case c
}

struct UserPreferences {
    struct Preference<Value> {
        let key: String
        let defaultValue: Value
        
        init(key: String, defaultValue: Value) {
            self.key = key
            self.defaultValue = defaultValue
        }
        
        init(key: String) where Value: ExpressibleByNilLiteral {
            self.key = key
            self.defaultValue = nil
        }
    }
    
    let rateLimt = Preference(key: "rateLimit", defaultValue: 50)
    let username = Preference(key: "username", defaultValue: "")
    let testItem = Preference<Int?>(key: "testItem")
    let ultimateTest = Preference(key: "ultimateTest", defaultValue: 50)
    let enumTest = Preference(key: "enumTestOne", defaultValue: MyTestEnum.a)
    let enumTest2 = Preference<MyTestEnum?>(key: "enumTestTwo")
    let intEnum = Preference(key: "intEnum", defaultValue: MyIntEnum.a)
    
    static let shared = UserPreferences()
    private init() {}
}


    // MARK: - AppStorage Extension for Non-Optionals
@available(iOS 14, macOS 11, macCatalyst 14, tvOS 14, watchOS 7, *)
extension AppStorage where Value == String {
    init(_ preferenceKeyPath: KeyPath<UserPreferences, UserPreferences.Preference<Value>>, store: UserDefaults? = nil) {
        let preference = UserPreferences.shared[keyPath: preferenceKeyPath]
        
        self.init(wrappedValue: preference.defaultValue,
                  preference.key,
                  store: store)
    }
}

@available(iOS 14, macOS 11, macCatalyst 14, tvOS 14, watchOS 7, *)
extension AppStorage where Value: RawRepresentable, Value.RawValue == Int {
    init(_ preferenceKeyPath: KeyPath<UserPreferences, UserPreferences.Preference<Value>>, store: UserDefaults? = nil) {
        let preference = UserPreferences.shared[keyPath: preferenceKeyPath]
        
        self.init(wrappedValue: preference.defaultValue,
                  preference.key,
                  store: store)
    }
}

@available(iOS 14, macOS 11, macCatalyst 14, tvOS 14, watchOS 7, *)
extension AppStorage where Value == Data {
    init(_ preferenceKeyPath: KeyPath<UserPreferences, UserPreferences.Preference<Value>>, store: UserDefaults? = nil) {
        let preference = UserPreferences.shared[keyPath: preferenceKeyPath]
        
        self.init(wrappedValue: preference.defaultValue,
                  preference.key,
                  store: store)
    }
}

@available(iOS 14, macOS 11, macCatalyst 14, tvOS 14, watchOS 7, *)
extension AppStorage where Value == Int {
    init(_ preferenceKeyPath: KeyPath<UserPreferences, UserPreferences.Preference<Value>>, store: UserDefaults? = nil) {
        let preference = UserPreferences.shared[keyPath: preferenceKeyPath]
        
        self.init(wrappedValue: preference.defaultValue,
                  preference.key,
                  store: store)
    }
}

@available(iOS 14, macOS 11, macCatalyst 14, tvOS 14, watchOS 7, *)
extension AppStorage where Value: RawRepresentable, Value.RawValue == String {
    init(_ preferenceKeyPath: KeyPath<UserPreferences, UserPreferences.Preference<Value>>, store: UserDefaults? = nil) {
        let preference = UserPreferences.shared[keyPath: preferenceKeyPath]
        
        self.init(wrappedValue: preference.defaultValue,
                  preference.key,
                  store: store)
    }
}

@available(iOS 14, macOS 11, macCatalyst 14, tvOS 14, watchOS 7, *)
extension AppStorage where Value == URL {
    init(_ preferenceKeyPath: KeyPath<UserPreferences, UserPreferences.Preference<Value>>, store: UserDefaults? = nil) {
        let preference = UserPreferences.shared[keyPath: preferenceKeyPath]
        
        self.init(wrappedValue: preference.defaultValue,
                  preference.key,
                  store: store)
    }
}

@available(iOS 14, macOS 11, macCatalyst 14, tvOS 14, watchOS 7, *)
extension AppStorage where Value == Double {
    init(_ preferenceKeyPath: KeyPath<UserPreferences, UserPreferences.Preference<Value>>, store: UserDefaults? = nil) {
        let preference = UserPreferences.shared[keyPath: preferenceKeyPath]
        
        self.init(wrappedValue: preference.defaultValue,
                  preference.key,
                  store: store)
    }
}

@available(iOS 14, macOS 11, macCatalyst 14, tvOS 14, watchOS 7, *)
extension AppStorage where Value == Bool {
    init(_ preferenceKeyPath: KeyPath<UserPreferences, UserPreferences.Preference<Value>>, store: UserDefaults? = nil) {
        let preference = UserPreferences.shared[keyPath: preferenceKeyPath]
        
        self.init(wrappedValue: preference.defaultValue,
                  preference.key,
                  store: store)
    }
}

    // MARK: - AppStorage Extension for ExpressibleByNilLiteral
@available(iOS 14, macOS 11, macCatalyst 14, tvOS 14, watchOS 7, *)
extension AppStorage where Value == Int? {
    init(_ preferenceKeyPath: KeyPath<UserPreferences, UserPreferences.Preference<Value>>, store: UserDefaults? = nil) {
        let preference = UserPreferences.shared[keyPath: preferenceKeyPath]
        
        self.init(preference.key,
                  store: store)
    }
}

@available(iOS 14, macOS 11, macCatalyst 14, tvOS 14, watchOS 7, *)
extension AppStorage where Value == String? {
    init(_ preferenceKeyPath: KeyPath<UserPreferences, UserPreferences.Preference<Value>>, store: UserDefaults? = nil) {
        let preference = UserPreferences.shared[keyPath: preferenceKeyPath]
        
        self.init(preference.key,
                  store: store)
    }
}

@available(iOS 14, macOS 11, macCatalyst 14, tvOS 14, watchOS 7, *)
extension AppStorage where Value == Double? {
    init(_ preferenceKeyPath: KeyPath<UserPreferences, UserPreferences.Preference<Value>>, store: UserDefaults? = nil) {
        let preference = UserPreferences.shared[keyPath: preferenceKeyPath]
        
        self.init(preference.key,
                  store: store)
    }
}

@available(iOS 15, macOS 12, macCatalyst 15, tvOS 15, watchOS 8, *)
extension AppStorage {
    init<R>(_ preferenceKeyPath: KeyPath<UserPreferences, UserPreferences.Preference<Value>>, store: UserDefaults? = nil)
    where Value == R?, R: RawRepresentable, R.RawValue == Int
    {
        let preference = UserPreferences.shared[keyPath: preferenceKeyPath]
        
        self.init(preference.key,
                  store: store)
    }
}

@available(iOS 15, macOS 12, macCatalyst 15, tvOS 15, watchOS 8, *)
extension AppStorage {
    init<R>(_ preferenceKeyPath: KeyPath<UserPreferences, UserPreferences.Preference<Value>>, store: UserDefaults? = nil)
    where Value == R?, R: RawRepresentable, R.RawValue == String
    {
        let preference = UserPreferences.shared[keyPath: preferenceKeyPath]
        
        self.init(preference.key,
                  store: store)
    }
}

@available(iOS 14, macOS 11, macCatalyst 14, tvOS 14, watchOS 7, *)
extension AppStorage where Value == Data? {
    init(_ preferenceKeyPath: KeyPath<UserPreferences, UserPreferences.Preference<Value>>, store: UserDefaults? = nil) {
        let preference = UserPreferences.shared[keyPath: preferenceKeyPath]
        
        self.init(preference.key,
                  store: store)
    }
}

@available(iOS 14, macOS 11, macCatalyst 14, tvOS 14, watchOS 7, *)
extension AppStorage where Value == Bool? {
    init(_ preferenceKeyPath: KeyPath<UserPreferences, UserPreferences.Preference<Value>>, store: UserDefaults? = nil) {
        let preference = UserPreferences.shared[keyPath: preferenceKeyPath]
        
        self.init(preference.key,
                  store: store)
    }
}

@available(iOS 14, macOS 11, macCatalyst 14, tvOS 14, watchOS 7, *)
extension AppStorage where Value == URL? {
    init(_ preferenceKeyPath: KeyPath<UserPreferences, UserPreferences.Preference<Value>>, store: UserDefaults? = nil) {
        let preference = UserPreferences.shared[keyPath: preferenceKeyPath]
        
        self.init(preference.key,
                  store: store)
    }
}

@available(iOS 17, macOS 14, macCatalyst 17, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
extension AppStorage {
    init<RowValue>(_ preferenceKeyPath: KeyPath<UserPreferences, UserPreferences.Preference<Value>>, store: UserDefaults? = nil)
    where Value == TableColumnCustomization<RowValue>, RowValue: Identifiable
    {
        let preference = UserPreferences.shared[keyPath: preferenceKeyPath]
        
        self.init(wrappedValue: preference.defaultValue,
                  preference.key,
                  store: store)
    }
}

@propertyWrapper
class UserDefault<Value> {
    private var defaultValue: Value
    private var key: String
    private var container: UserDefaults
    
    private var getter: () -> Value = {
        fatalError("UserDefault getter was not replaced during initialization")
            // return UserDefaults.standard.object(forKey: "willBeOverriden") as! Value
    }
    private var setter: (Value) -> Void = { _ in
        fatalError("UserDefault setter was not replaced during initialization")
    }
    
    var wrappedValue: Value {
        get { getter() }
        set { setter(newValue) }
    }
    
        // MARK: - Non-optional inits for supported types
    init(_ preferenceKeyPath: KeyPath<UserPreferences, UserPreferences.Preference<Value>>, store: UserDefaults = .standard)
    where Value == String {
        
        let preference = UserPreferences.shared[keyPath: preferenceKeyPath]
        
        self.defaultValue = preference.defaultValue
        self.key = preference.key
        self.container = store
        
        getter = { self.container.string(forKey: self.key) ?? self.defaultValue }
        setter = { self.container.set($0, forKey: self.key) }
    }
    
    init(_ preferenceKeyPath: KeyPath<UserPreferences, UserPreferences.Preference<Value>>, store: UserDefaults = .standard)
    where Value: RawRepresentable {
        
        let preference = UserPreferences.shared[keyPath: preferenceKeyPath]
        
        self.defaultValue = preference.defaultValue
        self.key = preference.key
        self.container = store
        
        getter = {
            guard let rawValue = self.container.object(forKey: self.key) as? Value.RawValue else { return self.defaultValue }
            return Value(rawValue: rawValue) ?? self.defaultValue
        }
        setter = { self.container.set($0.rawValue, forKey: self.key) }
    }
    
    init(_ preferenceKeyPath: KeyPath<UserPreferences, UserPreferences.Preference<Value>>, store: UserDefaults = .standard)
    where Value == Data {
        
        let preference = UserPreferences.shared[keyPath: preferenceKeyPath]
        
        self.defaultValue = preference.defaultValue
        self.key = preference.key
        self.container = store
        
        getter = { self.container.data(forKey: self.key) ?? self.defaultValue }
        setter = { self.container.set($0, forKey: self.key) }
    }
    
    init(_ preferenceKeyPath: KeyPath<UserPreferences, UserPreferences.Preference<Value>>, store: UserDefaults = .standard)
    where Value == Int {
        
        let preference = UserPreferences.shared[keyPath: preferenceKeyPath]
        
        self.defaultValue = preference.defaultValue
        self.key = preference.key
        self.container = store
        
        getter = { self.container.object(forKey: self.key) as? Int ?? self.defaultValue }
        setter = { self.container.set($0, forKey: self.key) }
    }
    
    init(_ preferenceKeyPath: KeyPath<UserPreferences, UserPreferences.Preference<Value>>, store: UserDefaults = .standard)
    where Value == URL {
        
        let preference = UserPreferences.shared[keyPath: preferenceKeyPath]
        
        self.defaultValue = preference.defaultValue
        self.key = preference.key
        self.container = store
        
        getter = { self.container.url(forKey: self.key) ?? self.defaultValue }
        setter = { self.container.set($0, forKey: self.key) }
    }
    
    init(_ preferenceKeyPath: KeyPath<UserPreferences, UserPreferences.Preference<Value>>, store: UserDefaults = .standard)
    where Value == Double {
        
        let preference = UserPreferences.shared[keyPath: preferenceKeyPath]
        
        self.defaultValue = preference.defaultValue
        self.key = preference.key
        self.container = store
        
        getter = { self.container.object(forKey: self.key) as? Double ?? self.defaultValue }
        setter = { self.container.set($0, forKey: self.key) }
    }
    
    init(_ preferenceKeyPath: KeyPath<UserPreferences, UserPreferences.Preference<Value>>, store: UserDefaults = .standard)
    where Value == Bool {
        
        let preference = UserPreferences.shared[keyPath: preferenceKeyPath]
        
        self.defaultValue = preference.defaultValue
        self.key = preference.key
        self.container = store
        
        getter = { self.container.object(forKey: self.key) as? Bool ?? self.defaultValue }
        setter = { self.container.set($0, forKey: self.key) }
    }
    
        // MARK: - Optional (ExpressibleByNilLiteral) initiatilzers
    init(_ preferenceKeyPath: KeyPath<UserPreferences, UserPreferences.Preference<Value>>, store: UserDefaults = .standard)
    where Value == Int? {
        
        let preference = UserPreferences.shared[keyPath: preferenceKeyPath]
        
        self.defaultValue = preference.defaultValue
        self.key = preference.key
        self.container = store
        
        getter = { self.container.object(forKey: self.key) as? Value ?? self.defaultValue }
        setter = { self.container.set($0, forKey: self.key) }
    }
    
    init(_ preferenceKeyPath: KeyPath<UserPreferences, UserPreferences.Preference<Value>>, store: UserDefaults = .standard)
    where Value == String? {
        
        let preference = UserPreferences.shared[keyPath: preferenceKeyPath]
        
        self.defaultValue = preference.defaultValue
        self.key = preference.key
        self.container = store
        
        getter = { self.container.object(forKey: self.key) as? Value ?? self.defaultValue }
        setter = { self.container.set($0, forKey: self.key) }
    }
    
    init(_ preferenceKeyPath: KeyPath<UserPreferences, UserPreferences.Preference<Value>>, store: UserDefaults = .standard)
    where Value == Double? {
        
        let preference = UserPreferences.shared[keyPath: preferenceKeyPath]
        
        self.defaultValue = preference.defaultValue
        self.key = preference.key
        self.container = store
        
        getter = { self.container.object(forKey: self.key) as? Value ?? self.defaultValue }
        setter = { self.container.set($0, forKey: self.key) }
    }
    
    init<R>(_ preferenceKeyPath: KeyPath<UserPreferences, UserPreferences.Preference<Value>>, store: UserDefaults = .standard)
    where Value == R?, R: RawRepresentable {
        
        let preference = UserPreferences.shared[keyPath: preferenceKeyPath]
        
        self.defaultValue = preference.defaultValue
        self.key = preference.key
        self.container = store
        
        getter = {
            guard let rawVal = self.container.object(forKey: self.key) as? R.RawValue else { return self.defaultValue }
            return R(rawValue: rawVal) ?? self.defaultValue
        }
        setter = {
            if let newValue = $0 {
                self.container.set(newValue.rawValue, forKey: self.key)
            } else {
                self.container.removeObject(forKey: self.key)
            }
        }
    }
    
    init(_ preferenceKeyPath: KeyPath<UserPreferences, UserPreferences.Preference<Value>>, store: UserDefaults = .standard)
    where Value == Data? {
        
        let preference = UserPreferences.shared[keyPath: preferenceKeyPath]
        
        self.defaultValue = preference.defaultValue
        self.key = preference.key
        self.container = store
        
        getter = { self.container.object(forKey: self.key) as? Value ?? self.defaultValue }
        setter = { self.container.set($0, forKey: self.key) }
    }
    
    init(_ preferenceKeyPath: KeyPath<UserPreferences, UserPreferences.Preference<Value>>, store: UserDefaults = .standard)
    where Value == Bool? {
        
        let preference = UserPreferences.shared[keyPath: preferenceKeyPath]
        
        self.defaultValue = preference.defaultValue
        self.key = preference.key
        self.container = store
        
        getter = { self.container.object(forKey: self.key) as? Value ?? self.defaultValue }
        setter = { self.container.set($0, forKey: self.key) }
    }
    
    init(_ preferenceKeyPath: KeyPath<UserPreferences, UserPreferences.Preference<Value>>, store: UserDefaults = .standard)
    where Value == URL? {
        
        let preference = UserPreferences.shared[keyPath: preferenceKeyPath]
        
        self.defaultValue = preference.defaultValue
        self.key = preference.key
        self.container = store
        
        getter = { self.container.object(forKey: self.key) as? Value ?? self.defaultValue }
        setter = { self.container.set($0, forKey: self.key) }
    }
}
