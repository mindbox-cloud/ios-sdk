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
    
    let appBundle: Bundle = {
        var bundle: Bundle = .main
        prepareBundle(&bundle)
        return bundle
    }()
    
    let sdkBundle: Bundle = {
        var bundle = Bundle(for: MindBox.self)
        prepareBundle(&bundle)
        return bundle
    }()
    
    var appGroup: String {
        guard let hostApplicationName = hostApplicationName else {
            fatalError("CFBundleShortVersionString not found for host app")
        }
        let identifier = "group.cloud.MindBox.\(hostApplicationName)"
        let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
        guard url != nil else {
            #if targetEnvironment(simulator)
            return ""
            #else
            fatalError("containerURL not found for group: \(identifier)")
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
