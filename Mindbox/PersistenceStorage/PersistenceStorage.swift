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

    func reset()

    func resetBackgroundExecutions()

    func storeToFileBackgroundExecution()
    
    func migrateShownInAppsIds()

    var onDidChange: (() -> Void)? { get set }
    
    var needUpdateInfoOnce: Bool? { get set }

    var userVisitCount: Int? { get set }
    
    var configDownloadDate: Date? { get set }
    
    var versionCodeForMigration: Int? { get set }
}
