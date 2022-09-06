//
//  InAppPresentChecker.swift
//  Mindbox
//
//  Created by Максим Казаков on 06.09.2022.
//  Copyright © 2022 Mikhail Barilov. All rights reserved.
//

import Foundation

/// Makes request to network and returns in-app messages that should be shown
class InAppPresentChecker {

    func getInAppToPresent(request: InAppRequest, _ completion: @escaping (InAppResponse?) -> Void) {
        // make network request to get if there're in apps to show for the client

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            completion(InAppResponse())
        }
    }
}
