//
//  UDIDRepository.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 02.02.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation
import AdSupport
import AppTrackingTransparency

struct IDFAFetcher {
    func fetch() -> UUID? {
        if #available(iOS 14, *) {
            switch ATTrackingManager.trackingAuthorizationStatus {
            case .authorized:
                return extract()
            default:
                return nil
            }
        } else {
            guard ASIdentifierManager.shared().isAdvertisingTrackingEnabled else {
                return nil
            }
            return extract()
        }
    }
    
    private func extract() -> UUID? {
        let udid = ASIdentifierManager.shared().advertisingIdentifier
        guard isValid(udid: udid.uuidString) else {
            return nil
        }
        return udid
    }
    
    private func isValid(udid: String) -> Bool {
        return UDIDValidator(udid: udid).evaluate()
    }
}
