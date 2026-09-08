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

/// Touched from every queue the SDK runs on. `@Locked` makes each access atomic; the single writer
/// per property is what keeps compound mutations (`append`, `insert`) safe without a wider transaction.
final class SessionTemporaryStorage {

    public static let shared = SessionTemporaryStorage()

    @Locked var observedCustomOperations: Set<String> = []
    @Locked var viewProductOperation: String?
    @Locked var viewCategoryOperation: String?
    @Locked var geoRequestResult: Result<InAppGeoResponse?, MindboxError>?
    @Locked var segmentationRequestResult: Result<[SegmentationCheckResponse.CustomerSegmentation]?, MindboxError>?
    @Locked var isPresentingInAppMessage = false
    @Locked var pushPermissionStatus: UNAuthorizationStatus = .denied
    @Locked var showBudget = InappShowBudgetState()
    @Locked var isInstalledFromPersistenceStorageBeforeInitSDK: Bool = false
    @Locked var isInitializationCalled = false {
        didSet {
            if isInitializationCalled, isInitializationCalled != oldValue {
                NotificationCenter.default.post(name: .initializationCompleted, object: nil)
            }
        }
    }

    @Locked var lastInappClickedID: String?

    @Locked var ledger = InappSessionLedger()

    /// Last track-visit data (source and requestUrl only)
    @Locked var lastTrackVisit: (source: TrackVisitSource?, requestUrl: String?)?

    @Locked var expiredConfigSession: String?
    @Locked var isUserVisitSaved = false
    @Locked var inAppSettings: Settings.InAppSettings?
    @Locked var configSessionExpirationTime: Date?

    private init() {}

    var sessionShownInApps: [String] {
        get { showBudget.shownInSession }
        set { $showBudget.mutate { $0.shownInSession = newValue } }
    }

    var customOperations: Set<String> {
        observedCustomOperations.union([viewCategoryOperation, viewProductOperation].compactMap { $0 })
    }

    func erase() {
        observedCustomOperations = []
        viewProductOperation = nil
        viewCategoryOperation = nil
        geoRequestResult = nil
        segmentationRequestResult = nil
        isPresentingInAppMessage = false
        showBudget = InappShowBudgetState()
        isUserVisitSaved = false
        lastInappClickedID = nil
        ledger = InappSessionLedger()
        lastTrackVisit = nil
        inAppSettings = nil
        configSessionExpirationTime = nil
        Logger.common(message: "[SessionTemporaryStorage] Erased.")
    }
}
