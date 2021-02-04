//
//  UDIDRepository.swift
//  MindBox
//
//  Created by Maksim Kazachkov on 02.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
import AdSupport
import AppTrackingTransparency

struct IDFAFetcher {
    
    typealias Completion = (UUID?) -> Void
    
    init() {}
    
    func fetch(completion: @escaping Completion) {
        if #available(iOS 14, *) {
            switch ATTrackingManager.trackingAuthorizationStatus {
            case .authorized:
                extract(completion: completion)
            case .notDetermined:
                guard Bundle.main.object(forInfoDictionaryKey: "NSUserTrackingUsageDescription") !=  nil else {
                    completion(nil)
                    return
                }
                ATTrackingManager.requestTrackingAuthorization { (status) in
                    if status == .authorized {
                        extract(completion: completion)
                    } else {
                        completion(nil)
                    }
                }
            default:
                completion(nil)
            }
        } else {
            extract(completion: completion)
        }
    }
    
    private func extract(completion: @escaping Completion) {
        DispatchQueue.global().async {
            guard ASIdentifierManager.shared().isAdvertisingTrackingEnabled else {
                completion(nil)
                return
            }
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
