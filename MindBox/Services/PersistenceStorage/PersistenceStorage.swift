//
//  PersistenceStorage.swift
//  MindBox
//
//  Created by Mikhail Barilov on 13.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

protocol IPersistenceStorage: class {

    var deviceUUID: String? {get set}
    var installationId: String? {get set}
    var wasInstaled: Bool {get set}

}

class MBPersistenceStorage: IPersistenceStorage {

    enum keys: String {
        case installationId = "installationId"
        case deviceUUID = "deviceUUID"
        case wasInstaled = "wasInstaled"
    }

    // MARK: - Elemets

    let defaults: UserDefaults

    // MARK: - Property

    // MARK: - Init
    
    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    // MARK: - IMBMBPersistenceStorage

    var deviceUUID: String? {
        get {
            return defaults.string(forKey: keys.deviceUUID.rawValue)
        }
        set {
            defaults.set(newValue, forKey: keys.deviceUUID.rawValue)
        }
    }

    var installationId: String? {
        get {
            return defaults.string(forKey: keys.installationId.rawValue)
        }
        set {
            defaults.set(newValue, forKey: keys.installationId.rawValue)
        }
    }

    var wasInstaled: Bool {
        get {
            defaults.bool(forKey: keys.wasInstaled.rawValue)
        }
        set {
            defaults.set(newValue, forKey: keys.wasInstaled.rawValue)
        }
    }

    // MARK: - Private

}
