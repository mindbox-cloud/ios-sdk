//
//  MBPersistenceStorage.swift
//  MindBox
//
//  Created by Maksim Kazachkov on 02.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

class MBPersistenceStorage: PersistenceStorage {
    
    // MARK: - Dependency
    static var defaults: UserDefaults = .standard
    
    // MARK: - Property
    var isInstalled: Bool {
        deviceUUID != nil
    }
    
    var apnsTokenSaveDate: Date? {
        get {
            let dateFormater = DateFormatter()
            dateFormater.dateStyle = .full
            dateFormater.timeStyle = .full
            if let dateString = apnsTokenSaveDateString {
                return dateFormater.date(from: dateString)
            } else {
                return nil
            }
        }
        set {
            let dataFormater = DateFormatter()
            dataFormater.dateStyle = .full
            dataFormater.timeStyle = .full
            if let date = newValue {
                apnsTokenSaveDateString = dataFormater.string(from: date)
            } else {
                apnsTokenSaveDateString = nil
            }
        }
    }
    
    var deprecatedEventsRemoveDate: Date? {
        get {
            let dateFormater = DateFormatter()
            dateFormater.dateStyle = .full
            dateFormater.timeStyle = .full
            if let dateString = deprecatedEventsRemoveDateString {
                return dateFormater.date(from: dateString)
            } else {
                return nil
            }
        }
        set {
            let dataFormater = DateFormatter()
            dataFormater.dateStyle = .full
            dataFormater.timeStyle = .full
            if let date = newValue {
                deprecatedEventsRemoveDateString = dataFormater.string(from: date)
            } else {
                deprecatedEventsRemoveDateString = nil
            }
        }
    }
    
    var configuration: MBConfiguration? {
        get {
            guard let data = configurationData else {
                return nil
            }
            return try? JSONDecoder().decode(MBConfiguration.self, from: data)
        }
        set {
            if let data = newValue {
                configurationData = try? JSONEncoder().encode(data)
            } else {
                configurationData = nil
            }
        }
    }
    
    // MARK: - Init
    init(defaults: UserDefaults) {
        MBPersistenceStorage.defaults = defaults
    }

    // MARK: - IMBMBPersistenceStorage
    @UserDefaultsWrapper(key: .deviceUUID, defaultValue: nil)
    var deviceUUID: String?

    @UserDefaultsWrapper(key: .installationId, defaultValue: nil)
    var installationId: String?

    @UserDefaultsWrapper(key: .apnsToken, defaultValue: nil)
    var apnsToken: String?

    @UserDefaultsWrapper(key: .apnsTokenSaveDate, defaultValue: nil)
    private var apnsTokenSaveDateString: String?
    
    @UserDefaultsWrapper(key: .deprecatedEventsRemoveDate, defaultValue: nil)
    private var deprecatedEventsRemoveDateString: String?
    
    @UserDefaultsWrapper(key: .configurationData, defaultValue: nil)
    private var configurationData: Data?

    func reset() {
        deviceUUID = nil
        installationId = nil
        apnsToken = nil
        apnsTokenSaveDate = nil
    }

    // MARK: - Private

}

extension MBPersistenceStorage {
    
    @propertyWrapper
    struct UserDefaultsWrapper<T> {
        
        enum Key: String {
            
            case installationId = "MBPersistenceStorage-installationId"
            case deviceUUID = "MBPersistenceStorage-deviceUUID"
            case apnsToken = "MBPersistenceStorage-apnsToken"
            case apnsTokenSaveDate = "MBPersistenceStorage-apnsTokenSaveDate"
            case deprecatedEventsRemoveDate = "MBPersistenceStorage-deprecatedEventsRemoveDate"
            case configurationData = "MBPersistenceStorage-configurationData"
        }
        
        private let key: Key
        private let defaultValue: T?
        
        init(key: Key, defaultValue: T?) {
            self.key = key
            self.defaultValue = defaultValue
        }
        
        var wrappedValue: T? {
            get {
                // Read value from UserDefaults
                return MBPersistenceStorage.defaults.value(forKey: key.rawValue) as? T ?? defaultValue
            }
            set {
                // Set value to UserDefaults
                MBPersistenceStorage.defaults.setValue(newValue, forKey: key.rawValue)
            }
        }
        
    }
    
}
