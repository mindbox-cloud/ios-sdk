//
//  AppDelegate.swift
//  Example
//
//  Created by Дмитрий Ерофеев on 29.03.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Mindbox
import Foundation
import UIKit

@main
class AppDelegate: MindboxAppDelegate {
    
    //https://developers.mindbox.ru/docs/ios-sdk-initialization
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        super.application(application, didFinishLaunchingWithOptions: launchOptions)
        
        do {
            let mindboxSdkConfig = try MBConfiguration(
                //To run the application on a physical device you need to change the endpoint
                //You should also change the application bundle ID in all targets, more details in the readme
                //You can still run the application on the simulator to see In-Apps
                endpoint: "Mpush-test.ReleaseExample.IosApp",
                domain: "api.mindbox.ru",
                subscribeCustomerIfCreated: true,
                shouldCreateCustomer: true
            )
            Mindbox.shared.initialization(configuration: mindboxSdkConfig)
        } catch  {
            print(error)
        }
        //https://developers.mindbox.ru/docs/ios-send-push-notifications-appdelegate
        registerForRemoteNotifications()
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
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

