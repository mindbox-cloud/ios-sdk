//
//  AppDelegate.swift
//  Example
//
//  Created by Дмитрий Ерофеев on 29.03.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Mindbox
import UIKit

import AppTrackingTransparency
import AdSupport
import SwiftUI

@main
class AppDelegate: MindboxAppDelegate {
    
    var window: UIWindow?
    
    //https://developers.mindbox.ru/docs/ios-sdk-initialization
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        super.application(application, didFinishLaunchingWithOptions: launchOptions)
        print(#function)
        if ATTrackingManager.trackingAuthorizationStatus != .notDetermined {
            initializeMindbox()
        }
        
        //https://developers.mindbox.ru/docs/ios-send-push-notifications-appdelegate
        registerForRemoteNotifications()
        
        window = UIWindow(frame: UIScreen.main.bounds)
        
        let viewModel = MainViewModel()
        window?.rootViewController = UIHostingController(rootView: MainView(viewModel: viewModel))
        window?.makeKeyAndVisible()
        
        return true
    }
    
    func initializeMindbox() {
        print(#function)
        do {
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
    
    override func applicationDidBecomeActive(_ application: UIApplication) {
        print(#function)
        if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            DispatchQueue.main.async {
                ATTrackingManager.requestTrackingAuthorization { status in
                    print("Inside AppDelegate ATTrackingManager.requestTrackingAuthorization")
                    self.initializeMindbox()
                }
            }
        }
    }

    // https://developer.apple.com/documentation/uikit/uiapplicationdelegate/3197905-application
//    func application(
//        _ application: UIApplication,
//        configurationForConnecting connectingSceneSession: UISceneSession,
//        options: UIScene.ConnectionOptions
//    ) -> UISceneConfiguration {
//        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
//    }
    
    //https://developers.mindbox.ru/docs/ios-send-push-notifications-appdelegate
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.list, .badge, .sound, .banner])
    }
    
    //https://developers.mindbox.ru/docs/ios-sdk-handle-tap
    override func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        //https://developers.mindbox.ru/docs/ios-sdk-methods
        print("Is mindbox notification: \(Mindbox.shared.isMindboxPush(userInfo: response.notification.request.content.userInfo))")
        if let mindboxPushNotification = Mindbox.shared.getMindboxPushData(userInfo: response.notification.request.content.userInfo),
           Mindbox.shared.isMindboxPush(userInfo: response.notification.request.content.userInfo),
           let uniqueKey = mindboxPushNotification.uniqueKey {
            Mindbox.shared.pushClicked(uniqueKey: uniqueKey)
        }
        
        super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
    }
    
    //https://developers.mindbox.ru/docs/ios-send-push-notifications-appdelegate
    func registerForRemoteNotifications() {
        UNUserNotificationCenter.current().delegate = self
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
            UNUserNotificationCenter.current().requestAuthorization(options: [ .alert, .sound, .badge]) { granted, error in
                print("Permission granted: \(granted)")
                if let error = error {
                    print("NotificationsRequestAuthorization failed with error: \(error.localizedDescription)")
                }
                Mindbox.shared.notificationsRequestAuthorization(granted: granted)
            }
        }
    }
}

