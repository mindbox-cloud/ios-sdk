//
//  MockInAppConfigurationDataFacade.swift
//  MindboxTests
//
//  Created by vailence on 04.03.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import UIKit
@testable import Mindbox

// swiftlint:disable force_unwrapping

class MockInAppConfigurationDataFacade: InAppConfigurationDataFacadeProtocol {

    let segmentationService: SegmentationServiceProtocol
    var targetingChecker: InAppTargetingCheckerProtocol
    let imageService: ImageDownloadServiceProtocol
    let tracker: InappTargetingTrackProtocol

    public var showArray: [String] = []
    public var targetingArray: [String] = []
    public var trackTargetingCalls: [(id: String?, tags: [String: String]?)] = []
    public var downloadImageError: MindboxError?
    public var imageDownloadFailures: [(inappId: String, details: String?)] = []
    public var downloadImageTags: [String: [String: String]?] = [:]
    public var collectedTargetingFailureIds: [Set<String>] = []
    public var collectedTagsByInappId: [[String: [String: String]]] = []

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
    }
}
