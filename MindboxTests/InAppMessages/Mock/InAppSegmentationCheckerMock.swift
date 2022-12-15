//
//  InAppSegmentationCheckerMock.swift
//  MindboxTests
//
//  Created by Максим Казаков on 14.09.2022.
//  Copyright © 2022 Mikhail Barilov. All rights reserved.
//

import Foundation
@testable import Mindbox

class InAppSegmentationCheckerMock: InAppSegmentationCheckerProtocol {
    var inAppToPresentResult: InAppResponse?
    var requestReceived: InAppsCheckRequest?
    
    func getInAppToPresent(request: InAppsCheckRequest, completionQueue: DispatchQueue, _ completion: @escaping (InAppResponse?) -> Void) {
        requestReceived = request
        completion(inAppToPresentResult)
    }
}
