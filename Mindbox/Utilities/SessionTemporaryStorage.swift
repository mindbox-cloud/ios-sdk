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

/// One in-app a block's page was allowed to draw — what `Inapp.Targeting` for a page's question is
/// deduplicated by: once per session, per block and in-app.
struct BlockOffer: Hashable {
    let blockInappId: String
    let inappId: String
}

/// A `delayTime` that ran out for an in-app at a place: a block coming back to the screen gets that
/// content at once instead of waiting again.
struct ServedPlaceDelay: Hashable {
    let place: String
    let inappId: String
}

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

    @Locked var vouchedInappIds: Set<String> = []

    /// The in-app each place last vouched for as its winner: its `Inapp.Targeting` pairs with the show,
    /// so it goes out again when the place changes what it shows and then changes back.
    @Locked var placeTargetedInappId: [String: String] = [:]

    @Locked var vouchedBlockOffers: Set<BlockOffer> = []

    /// Places whose block already reported that the SDK never answered — once per place per session.
    @Locked var placesReportedUnanswered: Set<String> = []

    @Locked var servedPlaceDelays: Set<ServedPlaceDelay> = []

    /// The in-app each place showed last — a block's show is accounted when this changes.
    @Locked var placeShownInappId: [String: String] = [:]

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
        placeTargetedInappId = [:]
        vouchedBlockOffers = []
        placesReportedUnanswered = []
        servedPlaceDelays = []
        placeShownInappId = [:]
        lastTrackVisit = nil
        inAppSettings = nil
        configSessionExpirationTime = nil
        Logger.common(message: "[SessionTemporaryStorage] Erased.")
    }
}
