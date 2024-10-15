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

    var backgroundExecutions: [BackgroudExecution] {
        if let data = MBPersistenceStorage.defaults.value(forKey: "backgroundExecution") as? Data {
            return (try? PropertyListDecoder().decode(Array<BackgroudExecution>.self, from: data)) ?? []
        } else {
            return []
        }
    }

    func setBackgroundExecution(_ value: BackgroudExecution) {
        var tasks = backgroundExecutions
        tasks.append(value)
        MBPersistenceStorage.defaults.set(try? PropertyListEncoder().encode(tasks), forKey: "backgroundExecution")
        MBPersistenceStorage.defaults.synchronize()
        onDidChange?()
    }

    func storeToFileBackgroundExecution() {
        let path = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BackgroundExecution.plist")

        // Swift Dictionary To Data.
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        do {
            let data = try encoder.encode(backgroundExecutions)
            try data.write(to: path)
            Logger.common(message: "Successfully storeToFileBackgroundExecution")
        } catch {
            Logger.common(message: "StoreToFileBackgroundExecution did failed with error: \(error.localizedDescription)")
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

    @UserDefaultsWrapper(key: .shownInAppsIds, defaultValue: nil)
    var shownInAppsIds: [String]?

    @UserDefaultsWrapper(key: .shownInAppsDictionary, defaultValue: [:])
    var shownInappsDictionary: [String: Date]?

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

    func softReset() {
        configDownloadDate = nil
        shownInappsDictionary = nil
        handledlogRequestIds = nil
        userVisitCount = 0
        resetBackgroundExecutions()
    }

    func resetBackgroundExecutions() {
        MBPersistenceStorage.defaults.removeObject(forKey: "backgroundExecution")
        MBPersistenceStorage.defaults.synchronize()
    }
}

// MARK: - Functions for unit testing

extension MBPersistenceStorage {

    func reset() {
        installationDate = nil
        deviceUUID = nil
        installationId = nil
        apnsToken = nil
        apnsTokenSaveDate = nil
        deprecatedEventsRemoveDate = nil
        configuration = nil
        isNotificationsEnabled = nil
        configDownloadDate = nil
        resetBackgroundExecutions()
    }
}

struct BackgroudExecution: Codable {

    let taskID: String

    let taskName: String

    let dateString: String

    let info: String
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
            case isNotificationsEnabled = "MBPersistenceStorage-isNotificationsEnabled"
            case installationData = "MBPersistenceStorage-installationData"
            case shownInAppsIds = "MBPersistenceStorage-shownInAppsIds"
            case shownInAppsDictionary = "MBPersistenceStorage-shownInAppsDictionary"
            case handledlogRequestIds = "MBPersistenceStorage-handledlogRequestIds"
            case imageLoadingMaxTimeInSeconds = "MBPersistenceStorage-imageLoadingMaxTimeInSeconds"
            case needUpdateInfoOnce = "MBPersistenceStorage-needUpdateInfoOnce"
            case userVisitCount = "MBPersistenceStorage-userVisitCount"
            case configDownloadDate = "MBPersistenceStorage-configDownloadDate"
            case versionCodeForMigration = "MBPersistenceStorage-versionCodeForMigration"
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
