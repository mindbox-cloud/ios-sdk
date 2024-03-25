//
//  UtilitiesFetcher.swift
//  MindboxNotifications
//
//  Created by Ihor Kandaurov on 22.06.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger
#if SWIFT_PACKAGE
import SDKVersionProvider
#endif

class MBUtilitiesFetcher {
    
    let appBundle: Bundle = {
        var bundle: Bundle = .main
        prepareBundle(&bundle)
        return bundle
    }()
    
    let sdkBundle: Bundle = {
        var bundle = Bundle(for: MindboxNotificationService.self)
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
            let message = "AppGroup for \(hostApplicationName) not found. Add AppGroup with value: \(identifier)"
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
                Logger.common(message: "MindboxNotifications: Successfully prepared bundle. bundle: \(bundle)", level: .info, category: .notification)
            }
        }
    }
    
    var appVerson: String? {
        appBundle.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String
    }
    
    var sdkVersion: String? {
        SDKVersionProvider.sdkVersion
    }
    
    var hostApplicationName: String? {
        appBundle.bundleIdentifier
    }
    
    var userDefaults: UserDefaults? {
        return UserDefaults(suiteName: applicationGroupIdentifier)
    }
    
    var configuration: MBConfiguration? {
        guard let data = userDefaults?.data(forKey: "MBPersistenceStorage-configurationData") else {
            Logger.common(message: "MindboxNotifications: Failed to get data from userDefaults for key 'MBPersistenceStorage-configurationData'", level: .error, category: .notification)
            return nil
        }
        Logger.common(message: "MindboxNotifications: Successfully received data for key 'MBPersistenceStorage-configurationData'. data: \(data)", level: .info, category: .notification)
        return try? JSONDecoder().decode(MBConfiguration.self, from: data)
    }
}
