//
//  InAppConfigurationManagerMock.swift
//  MindboxTests
//
//  Created by Максим Казаков on 14.09.2022.
//  Copyright © 2022 Mikhail Barilov. All rights reserved.
//

import Foundation
@testable import Mindbox

class InAppConfigurationManagerMock: InAppConfigurationManagerProtocol {
    var delegate: InAppConfigurationDelegate?
    
    func recalculateInapps(with name: String) {
        
    }

    func prepareConfiguration() {

    }

    var buildInAppRequestResult: InAppsCheckRequest?
    func buildInAppRequest(event: InAppMessageTriggerEvent) -> InAppsCheckRequest? {
        buildInAppRequestResult
    }

    var inAppFormDataResult: InAppFormData?
    var receivedInAppResponse: InAppResponse?
    func getInAppFormData(by inAppResponse: InAppResponse) -> InAppFormData? {
        receivedInAppResponse = inAppResponse
        return inAppFormDataResult
    }
}
