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
    var wasInstaled: Bool {get}
    var apnsToken: String? {get set}
    var apnsTokenSaveDate: Date? {get set}

}

class MBPersistenceStorage: IPersistenceStorage {

    enum keys: String {
        case installationId = "MBPersistenceStorage-installationId"
        case deviceUUID = "MBPersistenceStorage-deviceUUID"
        case wasInstaled = "MBPersistenceStorage-wasInstaled"
        case apnsToken = "MBPersistenceStorage-apnsToken"
        case apnsTokenSaveDate = "MBPersistenceStorage-apnsTokenSaveDate"
    }

    // MARK: - Elements

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
            self.deviceUUID != nil
        }
    }

    var apnsToken: String? {
        get {
            defaults.string(forKey: keys.apnsToken.rawValue)
        }
        set {
            defaults.set(newValue, forKey: keys.apnsToken.rawValue)
        }
    }

    var apnsTokenSaveDate: Date? {
        get {
            let dataFormater = DateFormatter()
            dataFormater.dateStyle = .full
            dataFormater.timeStyle = .full

            if let str = defaults.string(forKey: keys.apnsTokenSaveDate.rawValue) {
                return dataFormater.date(from: str)
            } else {
                return nil
            }
        }
        set {
            let dataFormater = DateFormatter()
            dataFormater.dateStyle = .full
            dataFormater.timeStyle = .full

            if let str = newValue {
                defaults.set(dataFormater.string(from: str) , forKey: keys.apnsTokenSaveDate.rawValue)
            } else {
                defaults.set(nil, forKey: keys.apnsTokenSaveDate.rawValue)
            }
        }
    }

    // MARK: - Private

}
