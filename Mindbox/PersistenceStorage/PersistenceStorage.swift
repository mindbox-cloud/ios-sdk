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

    var deprecatedEventsRemoveDate: Date? { get set }

    var configuration: MBConfiguration? { get set }

    var backgroundExecutions: [BackgroudExecution] { get }

    var isNotificationsEnabled: Bool? { get set }

    @available(*, deprecated, renamed: "shownInappsDictionary", message: "Use shownInappsDictionary since version 2.10.0")
    var shownInAppsIds: [String]? { get set }
    
    var shownInappsDictionary: [String: Date]? { get set }
    
    var handledlogRequestIds: [String]? { get set }
    
    var imageLoadingMaxTimeInSeconds: Double? { get set }

    func setBackgroundExecution(_ value: BackgroudExecution)

    func resetBackgroundExecutions()

    func storeToFileBackgroundExecution()

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
    
    /// Clears certain parts of the persistence storage to revert the system to a stable state.
    func softReset()
    
    // MARK: - Functions for testing
    
    /// Clears most parts of the persistence storage. It is used in unit tests.
    func reset()
}
