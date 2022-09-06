//
//  InAppConfigurationManager.swift
//  Mindbox
//
//  Created by Максим Казаков on 06.09.2022.
//  Copyright © 2022 Mikhail Barilov. All rights reserved.
//

import Foundation

class InAppConfigurationManager {
    func prepareConfiguration(_ completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            completion(true)
        }
    }

    func buildInAppRequest(event: String, _ completion: @escaping (InAppRequest?) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            completion(InAppRequest())
        }
    }

    func buildInAppMessage(inAppResponse: InAppResponse) -> InAppMessage {
        return InAppMessage()
    }
}
