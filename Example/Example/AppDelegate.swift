//
//  AppDelegate.swift
//  Example
//
//  Created by Дмитрий Ерофеев on 29.03.2024.
//

import Mindbox
import Foundation
import UIKit

@main
class AppDelegate: MindboxAppDelegate, InAppMessagesDelegate {
    
    //https://developers.mindbox.ru/docs/ios-sdk-initialization
    override func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        super.application(application, didFinishLaunchingWithOptions: launchOptions)
        
        do {
            let mindboxSdkConfig = try MBConfiguration(
                endpoint: "Mpush-test.ReleaseExample.IosApp",
                domain: "api.mindbox.ru",
                subscribeCustomerIfCreated: true,
                shouldCreateCustomer: true
            )
            Mindbox.shared.initialization(configuration: mindboxSdkConfig)
            Mindbox.shared.getDeviceUUID { deviceUUID in
                print(deviceUUID)
            }
            
            //https://developers.mindbox.ru/docs/in-app
            Mindbox.shared.inAppMessagesDelegate = self
        } catch  {
            print(error)
        }
        registerForRemoteNotifications()
        return true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    //https://developers.mindbox.ru/docs/ios-send-push-notifications-appdelegate
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert, .badge, .sound])
        
        //https://developers.mindbox.ru/docs/ios-sdk-methods
        print("Is mindbox notification: \(Mindbox.shared.isMindboxPush(userInfo: notification.request.content.userInfo))")
        print("Notification data: \(String(describing: Mindbox.shared.getMindboxPushData(userInfo: notification.request.content.userInfo)))")
        
        if let uniqueKey = Mindbox.shared.getMindboxPushData(userInfo: notification.request.content.userInfo)?.uniqueKey {
            Mindbox.shared.pushClicked(uniqueKey: uniqueKey)
        }
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
    
    //https://developers.mindbox.ru/docs/in-app
    func inAppMessageTapAction(id: String, url: URL?, payload: String) {
        print("inAppMessageTapAction")
    }
    
    //https://developers.mindbox.ru/docs/in-app
    func inAppMessageDismissed(id: String) {
        print("inAppMessageDismissed")
    }
}

