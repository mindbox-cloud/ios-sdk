//
//  AppDelegate_IDFA.swift
//  Example
//
//  Created by Sergei Semko on 10/7/24.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import UIKit
import Mindbox
import AppTrackingTransparency

// This is only one use case. It is necessary to adapt the approach to your specific use case.

@UIApplicationMain
class AppDelegate_IDFA: MindboxAppDelegate {
    
    //https://developers.mindbox.ru/docs/ios-sdk-initialization
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        super.application(application, didFinishLaunchingWithOptions: launchOptions)
        
        if #available(iOS 14, *) {
            if ATTrackingManager.trackingAuthorizationStatus != .notDetermined {
                initializeMindbox()
            }
        } else {
            initializeMindbox()
        }
        
        // ...
        return true
    }
    
    // If you're using scenes (iOS 13.0+), UIKit will not call this method. Use `sceneDidBecomeActive(_:)` instead.
    override func applicationDidBecomeActive(_ application: UIApplication) {
        if #available(iOS 14, *) {
            if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
                DispatchQueue.main.async {
                    ATTrackingManager.requestTrackingAuthorization { status in
                        self.initializeMindbox()
                    }
                }
            }
        }
    }
    
    func initializeMindbox() {
        do {
            //To run the application on a physical device you need to change the endpoint
            //You should also change the application bundle ID in all targets, more details in the readme
            //You can still run the application on the simulator to see In-Apps
            let mindboxSdkConfig = try MBConfiguration(
                endpoint: "Mpush-test.ReleaseExample.IosApp",
                domain: "api.mindbox.ru",
                subscribeCustomerIfCreated: true,
                shouldCreateCustomer: true
            )
            Mindbox.shared.initialization(configuration: mindboxSdkConfig)
        } catch {
            print(error.localizedDescription)
        }
    }
    
    // ...
}
