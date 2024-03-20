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
            Mindbox.shared.getDeviceUUID {deviceUUID in
                print(deviceUUID)
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
                    Mindbox.logger.log(level: .error, message: "NotificationsRequestAuthorization failed with error: \(error.localizedDescription)")
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
    
    //https://developers.mindbox.ru/docs/ios-get-click-advanced#1-%D0%BF%D0%B5%D1%80%D0%B5%D0%B4%D0%B0%D1%87%D0%B0-%D0%BA%D0%BB%D0%B8%D0%BA%D0%BE%D0%B2-%D0%BF%D0%BE-push-%D1%83%D0%B2%D0%B5%D0%B4%D0%BE%D0%BC%D0%BB%D0%B5%D0%BD%D0%B8%D1%8F%D0%BC
    //https://developers.mindbox.ru/docs/ios-sdk-methods#pushclicked
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void) {
            Mindbox.shared.pushClicked(response: response)
            completionHandler()
        }
    
    //https://developers.mindbox.ru/docs/ios-send-push-notifications-advanced#4-%D0%BF%D0%B5%D1%80%D0%B5%D0%B4%D0%B0%D1%82%D1%8C-%D0%B2-sdk-apns-%D1%82%D0%BE%D0%BA%D0%B5%D0%BD
    //https://developers.mindbox.ru/docs/ios-sdk-methods#apnstokenupdate
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Mindbox.shared.apnsTokenUpdate(deviceToken: deviceToken)
    }
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}



