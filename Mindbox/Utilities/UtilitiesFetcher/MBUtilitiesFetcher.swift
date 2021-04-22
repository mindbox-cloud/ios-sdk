//
//  FetchUtilities.swift
//  Mindbox
//
//  Created by Mikhail Barilov on 20.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
import AdSupport
import AppTrackingTransparency
import UIKit.UIDevice

class MBUtilitiesFetcher: UtilitiesFetcher {
    
    let appBundle: Bundle = {
        var bundle: Bundle = .main
        prepareBundle(&bundle)
        return bundle
    }()
    
    let sdkBundle: Bundle = {
        var bundle = Bundle(for: Mindbox.self)
        prepareBundle(&bundle)
        return bundle
    }()
    
    var applicationGroupIdentifier: String {
        guard let hostApplicationName = hostApplicationName else {
            fatalError("CFBundleShortVersionString not found for host app")
        }
        let identifier = "group.cloud.Mindbox.\(hostApplicationName)"
        let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
        guard url != nil else {
            #if targetEnvironment(simulator)
            return ""
            #else
            let message = "containerURL not found for group: \(identifier)"
            Log(message)
                .category(.general).level(.fault).make()
            fatalError(message)
            #endif
        }
        return identifier
    }
    
    init() {
        
    }
    
    private static func prepareBundle(_ bundle: inout Bundle) {
        if Bundle.main.bundleURL.pathExtension == "appex" {
            // Peel off two directory levels - MY_APP.app/PlugIns/MY_APP_EXTENSION.appex
            let url = bundle.bundleURL.deletingLastPathComponent().deletingLastPathComponent()
            if let otherBundle = Bundle(url: url) {
                bundle = otherBundle
            }
        }
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
        
    func getDeviceUUID(completion: @escaping (String) -> Void) {
        IDFAFetcher().fetch { (uuid) in
            if let uuid = uuid {
                Log("IDFAFetcher uuid:\(uuid.uuidString)")
                    .category(.general).level(.default).make()
                completion(uuid.uuidString)
            } else {
                Log("IDFAFetcher fail")
                    .category(.general).level(.default).make()
                IDFVFetcher().fetch(tryCount: 3) { (uuid) in
                    if let uuid = uuid {
                        Log("IDFVFetcher uuid:\(uuid.uuidString)")
                            .category(.general).level(.default).make()
                        completion(uuid.uuidString)
                    } else {
                        Log("IDFVFetcher fail")
                            .category(.general).level(.default).make()
                        let uuid = UUID()
                        completion(uuid.uuidString)
                        Log("Generated uuid:\(uuid.uuidString)")
                            .category(.general).level(.default).make()
                    }
                }
            }
        }
    }

}
