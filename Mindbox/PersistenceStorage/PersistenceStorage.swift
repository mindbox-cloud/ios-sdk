//
//  PersistenceStorage.swift
//  Mindbox
//
//  Created by Mikhail Barilov on 13.01.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation

protocol PersistenceStorage: AnyObject {
    var installationDate: Date? { get set }

    var deviceUUID: String? { get set }

    var installationId: String? { get set }

    var isInstalled: Bool { get }

    var apnsToken: String? { get set }

    var apnsTokenSaveDate: Date? { get set }
    
    var lastInfoUpdateDate: Date? { get set }

    var deprecatedEventsRemoveDate: Date? { get set }

    var configuration: MBConfiguration? { get set }

    var isNotificationsEnabled: Bool? { get set }

    var shownDatesByInApp: [String: [Date]]? { get set }
    
    var lastInappStateChangeDate: Date? { get set }

    var handledlogRequestIds: [String]? { get set }

    var imageLoadingMaxTimeInSeconds: Double? { get set }

    var onDidChange: (() -> Void)? { get set }

    var needUpdateInfoOnce: Bool? { get set }

    var userVisitCount: Int? { get set }

    /// The date when the InApps configuration was last downloaded.
    /// It is optional and can be set to `nil` if the configuration has not yet been downloaded yet or reset.
    var configDownloadDate: Date? { get set }

    /// The version code used to track the current state of migrations.
    /// This value is compared to `Constants.Migration.sdkVersionCode` to determine
    /// if migrations need to be performed. If a migration fails, and the `versionCodeForMigration`
    /// does not match the `Constants.Migration.sdkVersionCode`, a `softReset()` is performed to
    /// ensure that the system remains in a consistent state.
    var versionCodeForMigration: Int? { get set }
    
    // Metadata from the `DatabaseRepository`. Check `DatabaseMetadataMigration`.
    var applicationInfoUpdateVersion: Int? { get set }
    
    var applicationInstanceId: String? { get set }
    
    // Reset functions

    func softReset()
    
    /// Metadata: `ApplicationInfoUpdateVersion` and `InstanceId`
    func eraseMetadata()

    /// Hard reset for test purposes
    func reset()

    // MARK: - Deprecated Properties
    // These properties are deprecated and will be removed in future versions.
    // Please use the recommended alternatives instead.
    
    @available(*, deprecated, renamed: "shownInappsDictionary", message: "Use shownInappsDictionary since version 2.10.0")
    var shownInAppsIds: [String]? { get set }

    @available(*, deprecated, message: "Use shownDatesByInApp instead since 2.14.0")
    var shownInappsDictionary: [String: Date]? { get set }
}

extension PersistenceStorage {
    
    func eraseMetadata() {
        applicationInstanceId = nil
        applicationInfoUpdateVersion = nil
    }
    
    func softReset() {
        configDownloadDate = nil
        shownDatesByInApp = nil
        handledlogRequestIds = nil
        lastInappStateChangeDate = nil
        userVisitCount = 0
    }
}

// MARK: - Functions for unit testing

extension PersistenceStorage {
    func reset() {
        installationDate = nil
        deviceUUID = nil
        installationId = nil
        apnsToken = nil
        apnsTokenSaveDate = nil
        lastInfoUpdateDate = nil
        deprecatedEventsRemoveDate = nil
        configuration = nil
        isNotificationsEnabled = nil
        configDownloadDate = nil
        applicationInstanceId = nil
        applicationInfoUpdateVersion = nil
    }
}
