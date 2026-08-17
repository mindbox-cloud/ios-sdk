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

/// Session-scoped shared state, touched from every queue the SDK runs on. Every stored property is
/// `@Locked`, so each access is individually atomic; each property also keeps a single writer, which is
/// what makes the compound mutations (`append`, `insert`) safe without a wider transaction.
final class SessionTemporaryStorage {

    public static let shared = SessionTemporaryStorage()

    @Locked var observedCustomOperations: Set<String> = []
    @Locked var viewProductOperation: String?
    @Locked var viewCategoryOperation: String?
    @Locked var geoRequestResult: Result<InAppGeoResponse?, MindboxError>?
    @Locked var segmentationRequestResult: Result<[SegmentationCheckResponse.CustomerSegmentation]?, MindboxError>?
    @Locked var isPresentingInAppMessage = false
    @Locked var pushPermissionStatus: UNAuthorizationStatus = .denied
    @Locked var sessionShownInApps: [String] = []
    @Locked var isInstalledFromPersistenceStorageBeforeInitSDK: Bool = false
    @Locked var isInitializationCalled = false {
        didSet {
            if isInitializationCalled, isInitializationCalled != oldValue {
                NotificationCenter.default.post(name: .initializationCompleted, object: nil)
            }
        }
    }

    @Locked var lastInappClickedID: String?

    /// In-apps already vouched for on the paths that answer a page — a place resolve and a feed's
    /// question. Both repeat by design, and a repeated `Inapp.Targeting` would inflate the funnel by
    /// however often the user scrolled. The trigger path is deliberately not deduplicated here: a
    /// repeat there means a new event happened, and its own per-event map covers it.
    @Locked var vouchedInappIds: Set<String> = []

    /// Block in-apps whose `Inapp.Show` already went out this session — in sync with Android, down to
    /// the name. A page rebuilt within a session re-draws what the user already saw, so the event is
    /// not repeated; a different in-app winning the place is a new show and reports itself. The local
    /// show history is not deduplicated here — it is written per rendered page, on both platforms.
    @Locked var blockShowsReportedInSession: Set<String> = []

    /// Last track-visit data (source and requestUrl only)
    @Locked var lastTrackVisit: (source: TrackVisitSource?, requestUrl: String?)?

    @Locked var expiredConfigSession: String?
    @Locked var isUserVisitSaved = false
    @Locked var inAppSettings: Settings.InAppSettings?
    @Locked var configSessionExpirationTime: Date?

    private init() {}

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
        sessionShownInApps = []
        isUserVisitSaved = false
        lastInappClickedID = nil
        vouchedInappIds = []
        blockShowsReportedInSession = []
        lastTrackVisit = nil
        inAppSettings = nil
        configSessionExpirationTime = nil
        Logger.common(message: "[SessionTemporaryStorage] Erased.")
    }
}
