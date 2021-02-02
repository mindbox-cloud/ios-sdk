//
//  FetchUtilities.swift
//  MindBox
//
//  Created by Mikhail Barilov on 20.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
import AdSupport
import AppTrackingTransparency
import UIKit.UIDevice

class FetchUtilities: IFetchUtilities {

    let sdkBundle = Bundle.init(for: MindBox.self)
    let appBundle = Bundle.main

    init() {

    }

    private var advertising: UUID? {
        get {
            // Firstly, Check whether advertising tracking is enabled
            guard ASIdentifierManager.shared().isAdvertisingTrackingEnabled else {
                return nil
            }
            // Then, Get and return IDFA
            return ASIdentifierManager.shared().advertisingIdentifier
        }
    }

    var appVerson: String? {
        appBundle.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String
    }
    var sdkVersion: String? {
        get {
            return sdkBundle.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String

        }
    }

    var hostApplicationName: String? {
        get {
            return appBundle.bundleIdentifier
        }
    }
    
    func getUDID(completion: @escaping (UUID) -> Void) {
        IDFAFetcher().fetch { (uuid) in
            if let uuid = uuid {
                completion(uuid)
            } else {
                IDFVFetcher().fetch(tryCount: 3) { (uuid) in
                    if let uuid = uuid {
                        completion(uuid)
                    } else {
                        completion(UUID())
                    }
                }
            }
        }
    }

}
