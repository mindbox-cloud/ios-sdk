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

    var firstInitializationDateTime: Date? { get set }

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

    var configDownloadDate: Date? { get set }

    var operationsDomainFromConfig: String? { get set }

    var versionCodeForMigration: Int? { get set }
    
    var applicationInfoUpdateVersion: Int? { get set }
    
    var applicationInstanceId: String? { get set }

    var trackingIdsRecord: String? { get set }

    var webViewLocalStateVersion: Int? { get set }

    var webViewLearnedHosts: [String: [String]]? { get set }

    var embeddedBlockPlaceRecords: [String: Data]? { get set }

    func softReset()
    
    func eraseMetadata()

    func reset()

    // MARK: - Deprecated Properties
    
    @available(*, deprecated, renamed: "shownInappsDictionary", message: "Use shownInappsDictionary since version 2.10.0")
    var shownInAppsIds: [String]? { get set }

    @available(*, deprecated, message: "Use shownDatesByInApp instead since 2.14.0")
    var shownInappsDictionary: [String: Date]? { get set }
}

private let unconfirmedTrackingIdsReference = "unconfirmed"

extension PersistenceStorage {
    
    func eraseMetadata() {
        applicationInstanceId = nil
        applicationInfoUpdateVersion = nil
    }

    var trackingIdsReference: String? {
        guard let record = trackingIdsRecord, let separator = record.lastIndex(of: ":") else { return nil }
        guard record[..<separator] == applicationInstanceId ?? "" else { return unconfirmedTrackingIdsReference }
        return String(record[record.index(after: separator)...])
    }

    var isTrackingIdsReferenceUnconfirmed: Bool {
        trackingIdsReference == unconfirmedTrackingIdsReference
    }

    func acceptTrackingIdsHash(_ hash: String, instanceId: String?) {
        recordTrackingIds(hash, instanceId: instanceId)
    }

    func markTrackingIdsUnconfirmed(instanceId: String?) {
        recordTrackingIds(unconfirmedTrackingIdsReference, instanceId: instanceId)
    }

    private func recordTrackingIds(_ reference: String, instanceId: String?) {
        trackingIdsRecord = (instanceId ?? "") + ":" + reference
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
        firstInitializationDateTime = nil
        deviceUUID = nil
        installationId = nil
        apnsToken = nil
        apnsTokenSaveDate = nil
        lastInfoUpdateDate = nil
        deprecatedEventsRemoveDate = nil
        configuration = nil
        isNotificationsEnabled = nil
        configDownloadDate = nil
        operationsDomainFromConfig = nil
        applicationInstanceId = nil
        applicationInfoUpdateVersion = nil
        trackingIdsRecord = nil
        webViewLearnedHosts = nil
        embeddedBlockPlaceRecords = nil
    }
}
