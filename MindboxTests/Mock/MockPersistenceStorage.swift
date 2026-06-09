//
//  MockPersistenceStorage.swift
//  MindboxTests
//
//  Created by Mikhail Barilov on 29.01.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation
@testable import Mindbox

class MockPersistenceStorage: PersistenceStorage {

    var onDidChange: (() -> Void)?

    init() {}

    var deviceUUID: String? {
        didSet {
            configuration?.previousDeviceUUID = deviceUUID
            onDidChange?()
        }
    }

    var installationId: String? {
        didSet {
            onDidChange?()
        }
    }

    // Mirror production `MBPersistenceStorage`: installed state is the presence of a persisted
    // installation-date marker, never its parseability — not `installationDate != nil` directly.
    var isInstalled: Bool {
        installationDateString != nil
    }

    var apnsToken: String? {
        didSet {
            apnsTokenSaveDate = Date()
        }
    }

    var apnsTokenSaveDate: Date? {
        didSet {
            onDidChange?()
        }
    }

    var deprecatedEventsRemoveDate: Date? {
        didSet {
            onDidChange?()
        }
    }

    var configuration: MBConfiguration? {
        didSet {
            onDidChange?()
        }
    }

    var isNotificationsEnabled: Bool? {
        didSet {
            onDidChange?()
        }
    }

    // Presence marker for `isInstalled`, mirroring production's installation-date string. The Date
    // itself is stored as-is (no `.utc` flooring) so the mock keeps full precision like its other
    // date properties — only `isInstalled` is derived from the marker's presence.
    private var installationDateString: String?

    var installationDate: Date? {
        didSet {
            installationDateString = installationDate?.toString(withFormat: .utc)
            onDidChange?()
        }
    }

    var firstInitializationDateTime: Date? {
        didSet {
            onDidChange?()
        }
    }
    
    var lastInfoUpdateDate: Date? {
        didSet {
            onDidChange?()
        }
    }

    var shownInAppsIds: [String]?

    var shownInappsDictionary: [String: Date]?
    
    var shownDatesByInApp: [String : [Date]]?

    var lastInappStateChangeDate: Date?

    var handledlogRequestIds: [String]?

    var imageLoadingMaxTimeInSeconds: Double?

    private var _userVisitCount: Int? = 0

    var userVisitCount: Int? {
        get { return _userVisitCount }
        set { _userVisitCount = newValue }
    }

    private var _versionCodeForMigration: Int? = 0

    var versionCodeForMigration: Int? {
        get { return _versionCodeForMigration }
        set { _versionCodeForMigration = newValue }
    }

    var configDownloadDate: Date? {
        didSet {
            onDidChange?()
        }
    }

    var needUpdateInfoOnce: Bool? {
        didSet {
            onDidChange?()
        }
    }
    
    var applicationInfoUpdateVersion: Int?
    
    var applicationInstanceId: String?

    var webViewLocalStateVersion: Int?

    var operationsDomainFromConfig: String? {
        didSet {
            onDidChange?()
        }
    }
}
