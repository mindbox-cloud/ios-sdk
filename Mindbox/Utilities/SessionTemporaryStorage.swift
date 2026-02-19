//
//  SessionTemporaryStorage.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 10.03.2023.
//  Copyright © 2023 Mikhail Barilov. All rights reserved.
//

import Foundation
import UserNotifications
import MindboxLogger

final class SessionTemporaryStorage {

    public static let shared = SessionTemporaryStorage()

    var observedCustomOperations: Set<String> = []
    var viewProductOperation: String?
    var viewCategoryOperation: String?
    var geoRequestResult: Result<InAppGeoResponse?, MindboxError>?
    var checkSegmentsRequestCompleted = false
    var isPresentingInAppMessage = false
    var pushPermissionStatus: UNAuthorizationStatus = .denied
    var sessionShownInApps: [String] = []
    var isInstalledFromPersistenceStorageBeforeInitSDK: Bool = false
    var isInitializationCalled = false {
        didSet {
            if isInitializationCalled, isInitializationCalled != oldValue {
                NotificationCenter.default.post(name: .initializationCompleted, object: nil)
            }
        }
    }
    
    var lastInappClickedID: String?

    /// Last track-visit data (source and requestUrl only)
    var lastTrackVisit: (source: TrackVisitSource?, requestUrl: String?)?

    var expiredConfigSession: String?
    var isUserVisitSaved = false
    var inAppSettings: Settings.InAppSettings?
    var configSessionExpirationTime: Date?

    private init() {}

    var customOperations: Set<String> {
        observedCustomOperations.union([viewCategoryOperation, viewProductOperation].compactMap { $0 })
    }

    func erase() {
        observedCustomOperations = []
        viewProductOperation = nil
        viewCategoryOperation = nil
        geoRequestResult = nil
        checkSegmentsRequestCompleted = false
        isPresentingInAppMessage = false
        sessionShownInApps = []
        isUserVisitSaved = false
        lastInappClickedID = nil
        lastTrackVisit = nil
        inAppSettings = nil
        configSessionExpirationTime = nil
        Logger.common(message: "[SessionTemporaryStorage] Erased.")
    }
}
