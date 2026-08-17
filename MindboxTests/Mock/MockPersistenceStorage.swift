//
//  MockPersistenceStorage.swift
//  MindboxTests
//
//  Created by Mikhail Barilov on 29.01.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation
import class MindboxLogger.Locked
@testable import Mindbox

/// Every stored property is `@Locked`: production reaches this storage from background queues while tests assert from their own threads — TSan flagged the unsynchronized version.
class MockPersistenceStorage: PersistenceStorage {

    var onDidChange: (() -> Void)?

    init() {}

    @Locked var deviceUUID: String? {
        didSet {
            configuration?.previousDeviceUUID = deviceUUID
            onDidChange?()
        }
    }

    @Locked var installationId: String? {
        didSet {
            onDidChange?()
        }
    }

    // Mirror production `MBPersistenceStorage`: installed state is the presence of a persisted
    // installation-date marker, never its parseability — not `installationDate != nil` directly.
    var isInstalled: Bool {
        installationDateString != nil
    }

    @Locked var apnsToken: String? {
        didSet {
            apnsTokenSaveDate = Date()
        }
    }

    @Locked var apnsTokenSaveDate: Date? {
        didSet {
            onDidChange?()
        }
    }

    @Locked var deprecatedEventsRemoveDate: Date? {
        didSet {
            onDidChange?()
        }
    }

    @Locked var configuration: MBConfiguration? {
        didSet {
            onDidChange?()
        }
    }

    @Locked var isNotificationsEnabled: Bool? {
        didSet {
            onDidChange?()
        }
    }

    // Presence marker for `isInstalled`, mirroring production's installation-date string. The Date
    // itself is stored as-is (no `.utc` flooring) so the mock keeps full precision like its other
    // date properties — only `isInstalled` is derived from the marker's presence.
    @Locked private var installationDateString: String?

    @Locked var installationDate: Date? {
        didSet {
            installationDateString = installationDate?.toString(withFormat: .utc)
            onDidChange?()
        }
    }

    @Locked var firstInitializationDateTime: Date? {
        didSet {
            onDidChange?()
        }
    }

    @Locked var lastInfoUpdateDate: Date? {
        didSet {
            onDidChange?()
        }
    }

    @Locked var shownInAppsIds: [String]?

    @Locked var shownInappsDictionary: [String: Date]?

    @Locked var shownDatesByInApp: [String: [Date]]?

    @Locked var lastInappStateChangeDate: Date?

    @Locked var handledlogRequestIds: [String]?

    @Locked var imageLoadingMaxTimeInSeconds: Double?

    @Locked var userVisitCount: Int? = 0

    @Locked var versionCodeForMigration: Int? = 0

    @Locked var configDownloadDate: Date? {
        didSet {
            onDidChange?()
        }
    }

    @Locked var needUpdateInfoOnce: Bool? {
        didSet {
            onDidChange?()
        }
    }

    @Locked var applicationInfoUpdateVersion: Int?

    @Locked var applicationInstanceId: String?

    @Locked var webViewLocalStateVersion: Int?

    // Counts writes so a no-op-write regression (rewriting an unchanged dictionary) is
    // observable — the persisted value alone can't distinguish "written again" from "unchanged".
    @Locked var webViewLearnedHostsWriteCount = 0
    @Locked var webViewLearnedHosts: [String: [String]]? {
        didSet { webViewLearnedHostsWriteCount += 1 }
    }

    @Locked var operationsDomainFromConfig: String? {
        didSet {
            onDidChange?()
        }
    }
}
