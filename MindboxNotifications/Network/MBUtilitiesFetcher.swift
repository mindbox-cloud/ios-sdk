//
//  MBUtilitiesFetcher.swift
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

//class MBUtilitiesFetcher {
//    
//    let appBundle: Bundle = {
//        var bundle: Bundle = .main
//        prepareBundle(&bundle)
//        return bundle
//    }()
//    
//    let sdkBundle: Bundle = {
//        var bundle = Bundle(for: MindboxNotificationService.self)
//        return bundle
//    }()
//
//    var applicationGroupIdentifier: String? {
//        guard let hostApplicationName = hostApplicationName else {
//            Logger.common(message: "MBUtilitiesFetcher: Failed to get applicationGroupIdentifier. hostApplicationName: \(String(describing: hostApplicationName))", level: .error, category: .notification)
//            return nil
//        }
//        let identifier = "group.cloud.Mindbox.\(hostApplicationName)"
//        let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
//        guard url != nil else {
//            #if targetEnvironment(simulator)
//            return ""
//            #else
//            Logger.common(message: "MBUtilitiesFetcher: Failed to get AppGroup for \(hostApplicationName). identifier: \(identifier))", level: .error, category: .notification)
//            return nil
//            #endif
//        }
//        return identifier
//    }
//    
//    init() {
//        
//    }
//    
//    private static func prepareBundle(_ bundle: inout Bundle) {
//        if Bundle.main.bundleURL.pathExtension == "appex" {
//            // Peel off two directory levels - MY_APP.app/PlugIns/MY_APP_EXTENSION.appex
//            let url = bundle.bundleURL.deletingLastPathComponent().deletingLastPathComponent()
//            if let otherBundle = Bundle(url: url) {
//                bundle = otherBundle
//                Logger.common(message: "MBUtilitiesFetcher: Successfully prepared bundle. bundle: \(bundle)", level: .debug, category: .notification)
//            }
//        }
//    }
//    
//    var appVerson: String? {
//        appBundle.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String
//    }
//    
//    var sdkVersion: String? {
//        SDKVersionProvider.sdkVersion
//    }
//    
//    var hostApplicationName: String? {
//        appBundle.bundleIdentifier
//    }
//    
//    var userDefaults: UserDefaults? {
//        return UserDefaults(suiteName: applicationGroupIdentifier)
//    }
//    
//    var configuration: MBConfiguration? {
//        guard let data = userDefaults?.data(forKey: "MBPersistenceStorage-configurationData") else {
//            Logger.common(message: "MBUtilitiesFetcher: Failed to get data from userDefaults for key 'MBPersistenceStorage-configurationData'", level: .error, category: .notification)
//            return nil
//        }
//        return try? JSONDecoder().decode(MBConfiguration.self, from: data)
//    }
//}
