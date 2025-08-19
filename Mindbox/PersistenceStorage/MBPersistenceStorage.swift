//
//  MBPersistenceStorage.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 02.02.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

class MBPersistenceStorage: PersistenceStorage {

    var onDidChange: (() -> Void)?

    // MARK: - Dependency
    static var defaults: UserDefaults = .standard

    private let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .full
        return dateFormatter
    }()

    // MARK: - Property
    var isInstalled: Bool {
        installationDate != nil
    }

    var installationDate: Date? {
        get {
            if let dateString = installationDateString {
                return dateFormatter.date(from: dateString)
            } else {
                return nil
            }
        }
        set {
            if let date = newValue {
                installationDateString = dateFormatter.string(from: date)
            } else {
                installationDateString = nil
            }
        }
    }

    var apnsTokenSaveDate: Date? {
        get {
            if let dateString = apnsTokenSaveDateString {
                return dateFormatter.date(from: dateString)
            } else {
                return nil
            }
        }
        set {
            if let date = newValue {
                apnsTokenSaveDateString = dateFormatter.string(from: date)
            } else {
                apnsTokenSaveDateString = nil
            }
        }
    }
    
    var lastInfoUpdateDate: Date? {
        get {
            if let dateString = lastInfoUpdateDateString {
                return dateFormatter.date(from: dateString)
            } else {
                return nil
            }
        }
        
        set {
            if let date = newValue {
                lastInfoUpdateDateString = dateFormatter.string(from: date)
            } else {
                lastInfoUpdateDateString = nil
            }
        }
    }

    var deprecatedEventsRemoveDate: Date? {
        get {
            if let dateString = deprecatedEventsRemoveDateString {
                return dateFormatter.date(from: dateString)
            } else {
                return nil
            }
        }
        set {
            if let date = newValue {
                deprecatedEventsRemoveDateString = dateFormatter.string(from: date)
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

    var configDownloadDate: Date? {
        get {
            if let dateString = configDownloadDateString {
                return dateFormatter.date(from: dateString)
            } else {
                return nil
            }
        }
        set {
            if let date = newValue {
                configDownloadDateString = dateFormatter.string(from: date)
            } else {
                configDownloadDateString = nil
            }
        }
    }

    init(defaults: UserDefaults) {
        MBPersistenceStorage.defaults = defaults
    }

    @UserDefaultsWrapper(key: .deviceUUID, defaultValue: nil)
    var deviceUUID: String? {
        didSet {
            configuration?.previousDeviceUUID = deviceUUID
            onDidChange?()
        }
    }

    @UserDefaultsWrapper(key: .installationId, defaultValue: nil)
    var installationId: String? {
        didSet {
            onDidChange?()
        }
    }

    @UserDefaultsWrapper(key: .apnsToken, defaultValue: nil)
    var apnsToken: String? {
        didSet {
            apnsTokenSaveDate = Date()
            onDidChange?()
        }
    }

    @UserDefaultsWrapper(key: .shownDatesByInApp, defaultValue: [:])
    var shownDatesByInApp: [String: [Date]]?

    @UserDefaultsWrapper(key: .lastInappStateChangeDate, defaultValue: nil)
    var lastInappStateChangeDate: Date?

    @UserDefaultsWrapper(key: .handledlogRequestIds, defaultValue: nil)
    var handledlogRequestIds: [String]?

    @UserDefaultsWrapper(key: .imageLoadingMaxTimeInSeconds, defaultValue: nil)
    var imageLoadingMaxTimeInSeconds: Double?

    @UserDefaultsWrapper(key: .apnsTokenSaveDate, defaultValue: nil)
    private var apnsTokenSaveDateString: String? {
        didSet {
            onDidChange?()
        }
    }

    @UserDefaultsWrapper(key: .deprecatedEventsRemoveDate, defaultValue: nil)
    private var deprecatedEventsRemoveDateString: String? {
        didSet {
            onDidChange?()
        }
    }

    @UserDefaultsWrapper(key: .configurationData, defaultValue: nil)
    private var configurationData: Data? {
        didSet {
            onDidChange?()
        }
    }

    @UserDefaultsWrapper(key: .isNotificationsEnabled, defaultValue: nil)
    var isNotificationsEnabled: Bool? {
        didSet {
            onDidChange?()
        }
    }

    @UserDefaultsWrapper(key: .installationData, defaultValue: nil)
    private var installationDateString: String? {
        didSet {
            onDidChange?()
        }
    }

    @UserDefaultsWrapper(key: .needUpdateInfoOnce, defaultValue: nil)
    var needUpdateInfoOnce: Bool? {
        didSet {
            onDidChange?()
        }
    }

    @UserDefaultsWrapper(key: .userVisitCount, defaultValue: 0)
    var userVisitCount: Int? {
        didSet {
            onDidChange?()
        }
    }

    @UserDefaultsWrapper(key: .versionCodeForMigration, defaultValue: 0)
    var versionCodeForMigration: Int?

    @UserDefaultsWrapper(key: .configDownloadDate, defaultValue: nil)
    private var configDownloadDateString: String? {
        didSet {
            onDidChange?()
        }
    }
    
    @UserDefaultsWrapper(key: .lastInfoUpdateTime, defaultValue: nil)
    var lastInfoUpdateDateString: String? {
        didSet {
            onDidChange?()
        }
    }
    // MARK: - Deprecated Properties
    // These properties are deprecated and will be removed in future versions.
    // Please use the recommended alternatives instead.
    
    @UserDefaultsWrapper(key: .shownInAppsIds, defaultValue: nil)
    var shownInAppsIds: [String]?

    @UserDefaultsWrapper(key: .shownInAppsDictionary, defaultValue: [:])
    var shownInappsDictionary: [String: Date]?
}

extension MBPersistenceStorage {

    @propertyWrapper
    struct UserDefaultsWrapper<T> {

        enum Key: String {
            case installationId = "MBPersistenceStorage-installationId"
            case deviceUUID = "MBPersistenceStorage-deviceUUID"
            case apnsToken = "MBPersistenceStorage-apnsToken"
            case apnsTokenSaveDate = "MBPersistenceStorage-apnsTokenSaveDate"
            case lastInfoUpdateTime = "MBPersistenceStorage-lastInfoUpdateTime"
            case deprecatedEventsRemoveDate = "MBPersistenceStorage-deprecatedEventsRemoveDate"
            case configurationData = "MBPersistenceStorage-configurationData"
            case isNotificationsEnabled = "MBPersistenceStorage-isNotificationsEnabled"
            case installationData = "MBPersistenceStorage-installationData"
            case shownDatesByInApp = "MBPersistenceStorage-shownDatesByInApp"
            case lastInappStateChangeDate = "MBPersistenceStorage-lastInappStateChangeDate"
            case handledlogRequestIds = "MBPersistenceStorage-handledlogRequestIds"
            case imageLoadingMaxTimeInSeconds = "MBPersistenceStorage-imageLoadingMaxTimeInSeconds"
            case needUpdateInfoOnce = "MBPersistenceStorage-needUpdateInfoOnce"
            case userVisitCount = "MBPersistenceStorage-userVisitCount"
            case configDownloadDate = "MBPersistenceStorage-configDownloadDate"
            case versionCodeForMigration = "MBPersistenceStorage-versionCodeForMigration"

            // MARK: - Deprecated Keys
            // These keys are deprecated and will be removed in future versions.
            // Please use the recommended alternatives instead.
            
            case shownInAppsIds = "MBPersistenceStorage-shownInAppsIds"
            case shownInAppsDictionary = "MBPersistenceStorage-shownInAppsDictionary"
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
                let isExists = defaults.isValueExists(forKey: key.rawValue)
                let value = MBPersistenceStorage.defaults.value(forKey: key.rawValue) as? T ?? defaultValue
                return isExists ? value : defaultValue
            }
            set {
                // Set value to UserDefaults
                MBPersistenceStorage.defaults.setValue(newValue, forKey: key.rawValue)
                MBPersistenceStorage.defaults.synchronize()
            }
        }
    }
}

fileprivate extension UserDefaults {

    func isValueExists(forKey key: String) -> Bool {
        return object(forKey: key) != nil
    }
}
