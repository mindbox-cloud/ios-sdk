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

    @Locked var webViewLearnedHostsWriteCount = 0
    @Locked var webViewLearnedHosts: [String: [String]]? {
        didSet { webViewLearnedHostsWriteCount += 1 }
    }

    @Locked var embeddedBlockPlaceRecordsWriteCount = 0
    @Locked var embeddedBlockPlaceRecords: [String: Data]? {
        didSet { embeddedBlockPlaceRecordsWriteCount += 1 }
    }

    @Locked var operationsDomainFromConfig: String? {
        didSet {
            onDidChange?()
        }
    }
}

final class HostObservedHistoryStorage: MockPersistenceStorage {

    @Locked private(set) var hostObserverRuns = 0
    @Locked private(set) var hasFoundTheLedgerHeld = false
    var shownDatesWillBeWritten: () -> Void = {}
    private let suiteName: String
    private let defaults: UserDefaults
    private var observer: NSObjectProtocol?

    init?(suiteId: UUID = UUID()) {
        let suiteName = "MindboxTests.HostObservedHistoryStorage.\(suiteId.uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else { return nil }

        self.suiteName = suiteName
        self.defaults = defaults
        super.init()
        shownDatesByInApp = [:]
        observer = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: defaults, queue: nil) { [weak self] _ in
            let isLedgerRead = DispatchSemaphore(value: 0)
            Thread.detachNewThread {
                _ = SessionTemporaryStorage.shared.ledger.sessionEpoch
                isLedgerRead.signal()
            }
            if isLedgerRead.wait(timeout: .now() + 5) == .timedOut {
                self?.hasFoundTheLedgerHeld = true
            }
            self?.$hostObserverRuns.mutate { $0 += 1 }
        }
    }

    deinit {
        observer.map(NotificationCenter.default.removeObserver)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override var shownDatesByInApp: [String: [Date]]? {
        willSet { shownDatesWillBeWritten() }
        didSet { defaults.set(shownDatesByInApp, forKey: "shownDatesByInApp") }
    }

    override var lastInappStateChangeDate: Date? {
        didSet { defaults.set(lastInappStateChangeDate, forKey: "lastInappStateChangeDate") }
    }
}
