//
//  MockInAppConfigurationDataFacade.swift
//  MindboxTests
//
//  Created by vailence on 04.03.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import UIKit
import class MindboxLogger.Locked
@testable import Mindbox

// swiftlint:disable force_unwrapping

// Spy state is @Locked: the selection calls in on its own queues while tests read from theirs — TSan flagged the unsynchronized version.
class MockInAppConfigurationDataFacade: InAppConfigurationDataFacadeProtocol {

    let segmentationService: SegmentationServiceProtocol
    var targetingChecker: InAppTargetingCheckerProtocol
    let imageService: ImageDownloadServiceProtocol
    let tracker: InappTargetingTrackProtocol

    @Locked public var showArray: [String] = []
    @Locked public var targetingArray: [String] = []
    @Locked public var trackTargetingCalls: [(id: String?, tags: [String: String]?)] = []
    @Locked public var downloadImageError: MindboxError?
    @Locked public var imageDownloadFailures: [(inappId: String, details: String?)] = []
    @Locked public var downloadImageTags: [String: [String: String]?] = [:]
    @Locked public var collectedTargetingFailureIds: [Set<String>] = []
    @Locked public var collectedTagsByInappId: [[String: [String: String]]] = []
    @Locked public var fetchDependenciesCalls = 0
    @Locked public var sendCollectedFailuresCalls = 0

    init(segmentationService: SegmentationServiceProtocol,
         targetingChecker: InAppTargetingCheckerProtocol,
         imageService: ImageDownloadServiceProtocol,
         tracker: InappTargetingTrackProtocol) {
        self.segmentationService = segmentationService
        self.targetingChecker = targetingChecker
        self.imageService = imageService
        self.tracker = tracker
    }

    func fetchDependencies(
        model: InappOperationJSONModel?,
        shouldCollectFailures: Bool,
        _ completion: @escaping () -> Void
    ) {
        fetchDependenciesCalls += 1
        completion()
    }

    func downloadImage(withUrl url: String, inappId: String, tags: [String: String]?, completion: @escaping (Result<UIImage, MindboxError>) -> Void) {
        downloadImageTags[inappId] = tags
        if let downloadImageError {
            switch downloadImageError {
            case .serverError, .protocolError, .unknown:
                let details = "Image URL: \(url). \(downloadImageError.localizedDescription)"
                imageDownloadFailures.append((inappId: inappId, details: details))
            default:
                break
            }
            completion(.failure(downloadImageError))
            return
        }
        if #available(iOS 13.0, *) {
            let image = UIImage(systemName: "star")
            completion(.success(image!))
        } else {
            completion(.success(UIImage()))
        }
    }

    func collectTargetingFailures(forFailedTargetingInappIds failedTargetingInappIds: Set<String>, tagsByInappId: [String: [String: String]]) {
        collectedTargetingFailureIds.append(failedTargetingInappIds)
        collectedTagsByInappId.append(tagsByInappId)
    }

    func sendCollectedFailures() {
        sendCollectedFailuresCalls += 1
    }

    func trackTargeting(id: String?, tags: [String: String]?) {
        trackTargetingCalls.append((id: id, tags: tags))
        if let id = id {
            if showArray.isEmpty {
                showArray.append(id)
            }

            targetingArray.append(id)
        }
    }

    func cleanTargetingArray() {
        targetingArray = []
        trackTargetingCalls = []
    }

    func cleanImageDownloadFailures() {
        imageDownloadFailures = []
        downloadImageTags = [:]
    }

    func cleanCollectedTargetingFailureIds() {
        collectedTargetingFailureIds = []
        collectedTagsByInappId = []
        sendCollectedFailuresCalls = 0
    }
}
