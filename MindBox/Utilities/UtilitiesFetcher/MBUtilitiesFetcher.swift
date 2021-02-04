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

class MBUtilitiesFetcher: UtilitiesFetcher {

    let appBundle = Bundle.main
    let sdkBundle = Bundle(for: MindBox.self)

    init() {

    }
    
    var appVerson: String? {
        appBundle.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String
    }
    
    var sdkVersion: String? {
        sdkBundle.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String
    }

    var hostApplicationName: String? {
        appBundle.bundleIdentifier
    }
    
    func getUDID(completion: @escaping (UUID) -> Void) {
        IDFAFetcher().fetch { (uuid) in
            if let uuid = uuid {
                Log("IDFAFetcher uuid:\(uuid.uuidString)")
                    .inChanel(.system).withType(.verbose).make()
                completion(uuid)
            } else {
                Log("IDFAFetcher fail")
                    .inChanel(.system).withType(.verbose).make()
                IDFVFetcher().fetch(tryCount: 3) { (uuid) in
                    if let uuid = uuid {
                        Log("IDFVFetcher uuid:\(uuid.uuidString)")
                            .inChanel(.system).withType(.verbose).make()
                        completion(uuid)
                    } else {
                        Log("IDFVFetcher fail")
                            .inChanel(.system).withType(.verbose).make()
                        let uuid = UUID()
                        completion(uuid)
                        Log("Generated uuid:\(uuid.uuidString)")
                            .inChanel(.system).withType(.verbose).make()
                    }
                }
            }
        }
    }

}
