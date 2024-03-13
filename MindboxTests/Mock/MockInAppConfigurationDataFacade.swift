//
//  MockInAppConfigurationDataFacade.swift
//  MindboxTests
//
//  Created by vailence on 04.03.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation
import UIKit
@testable import Mindbox

class MockInAppConfigurationDataFacade: InAppConfigurationDataFacadeProtocol {
    
    let geoService: GeoServiceProtocol
    let segmentationService: SegmentationServiceProtocol
    let sessionTemporaryStorage: SessionTemporaryStorage
    var targetingChecker: InAppTargetingCheckerProtocol
    let imageService: ImageDownloadServiceProtocol
    let tracker: InappTargetingTrackProtocol
    
    public var showArray: [String] = []
    public var targetingArray: [String] = []
    
    init(geoService: GeoServiceProtocol,
         segmentationService: SegmentationServiceProtocol,
         sessionTemporaryStorage: SessionTemporaryStorage,
         targetingChecker: InAppTargetingCheckerProtocol,
         imageService: ImageDownloadServiceProtocol,
         tracker: InappTargetingTrackProtocol) {
        self.geoService = geoService
        self.segmentationService = segmentationService
        self.sessionTemporaryStorage = sessionTemporaryStorage
        self.targetingChecker = targetingChecker
        self.imageService = imageService
        self.tracker = tracker
    }
    
    func fetchDependencies(model: InappOperationJSONModel?, _ completion: @escaping () -> Void) {
        completion()
    }
    
    func setObservedOperation() {
        sessionTemporaryStorage.observedCustomOperations = Set(targetingChecker.context.operationsName)
    }

    func downloadImage(withUrl url: String, completion: @escaping (Result<UIImage, Error>) -> Void) {
        if #available(iOS 13.0, *) {
            let image = UIImage(systemName: "star")
            completion(.success(image!))
        } else {
            completion(.success(UIImage()))
        }
    }
    
    func trackTargeting(id: String?) {
        if let id = id {
            if showArray.isEmpty {
                showArray.append(id)
            }
            
            targetingArray.append(id)
        }
    }
    
    func clean() {
        targetingArray = []
    }
}
