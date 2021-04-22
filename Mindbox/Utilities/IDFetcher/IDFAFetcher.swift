//
//  UDIDRepository.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 02.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
import AdSupport
import AppTrackingTransparency

struct IDFAFetcher {
    
    typealias Completion = (UUID?) -> Void
        
    func fetch(completion: @escaping Completion) {
        if #available(iOS 14, *) {
            switch ATTrackingManager.trackingAuthorizationStatus {
            case .authorized:
                extract(completion: completion)
            default:
                completion(nil)
            }
        } else {
            guard ASIdentifierManager.shared().isAdvertisingTrackingEnabled else {
                completion(nil)
                return
            }
            extract(completion: completion)
        }
    }
    
    private func extract(completion: @escaping Completion) {
        DispatchQueue.global().sync {
            let udid = ASIdentifierManager.shared().advertisingIdentifier
            if isValid(udid: udid.uuidString) {
                completion(udid)
            } else {
                completion(nil)
            }
        }
    }
    
    private func isValid(udid: String) -> Bool {
        return UDIDValidator(udid: udid).evaluate()
    }
    
}
