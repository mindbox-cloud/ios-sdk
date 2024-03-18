//
//  AppDelegate.swift
//  ExampleApp
//
//  Created by Дмитрий Ерофеев on 11.03.2024.
//

import UIKit
import Mindbox
import Foundation


@main
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    //https://developers.mindbox.ru/docs/ios-sdk-initialization
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        do {
            let mindboxSdkConfig = try MBConfiguration(
                endpoint: "Mpush-test.ExampleApp.IosApp",
                domain: "api.mindbox.ru",
                subscribeCustomerIfCreated: true,
                shouldCreateCustomer: true
            )
            Mindbox.shared.initialization(configuration: mindboxSdkConfig)
            Mindbox.shared.getDeviceUUID {
                deviceUUID in print(deviceUUID)
            }
        } catch  {
            Mindbox.logger.log(level: .error, message: "\(error)")
        }
        registerForRemoteNotifications()
        return true
    }
    
    //https://developers.mindbox.ru/docs/ios-send-push-notifications-advanced
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
    
    //https://developers.mindbox.ru/docs/ios-send-push-notifications-advanced
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.alert, .badge, .sound])
    }
    
    //https://developers.mindbox.ru/docs/ios-app-start-tracking-advanced
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void) {
            Mindbox.shared.pushClicked(response: response)
            completionHandler()
        }
    
    //https://developers.mindbox.ru/docs/ios-send-push-notifications-advanced
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
            Mindbox.shared.apnsTokenUpdate(deviceToken: deviceToken)
        }
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}



