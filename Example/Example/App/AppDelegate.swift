//
//  AppDelegate.swift
//  Example
//
//  Created by Дмитрий Ерофеев on 29.03.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Mindbox
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    // https://developers.mindbox.ru/docs/ios-sdk-initialization
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        Mindbox.shared.registerBGTasks()
        Mindbox.shared.track(.launch(launchOptions))

        do {
            // To run the application on a physical device you need to change the endpoint
            // You should also change the application bundle ID in all targets, more details in the readme
            // You can still run the application on the simulator to see In-Apps
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
        
        // https://developers.mindbox.ru/docs/ios-send-push-notifications-appdelegate
        registerForRemoteNotifications()
        
        return true
    }
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Mindbox.shared.apnsTokenUpdate(deviceToken: deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("Failed to register for remote notifications: \(error.localizedDescription)")
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        Mindbox.shared.application(application, performFetchWithCompletionHandler: completionHandler)
    }

    // https://developers.mindbox.ru/docs/ios-quick-setup-push-notifications
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.list, .badge, .sound, .banner])
    }
    
    // https://developers.mindbox.ru/docs/ios-push-notification-deep-linking
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let click = ClientGateClick(response: response) {
            ClientGateClickReporter.shared.report(click)
        }
        Mindbox.shared.track(.push(response))
        completionHandler()
    }
    
    // https://developers.mindbox.ru/docs/ios-quick-setup-push-notifications
    func registerForRemoteNotifications() {
        UNUserNotificationCenter.current().delegate = self
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
            UNUserNotificationCenter.current().requestAuthorization(options: [ .alert, .sound, .badge]) { granted, error in
                print("Permission granted to allow local and remote notifications for your app: \(granted)")
                if let error = error {
                    print("NotificationsRequestAuthorization failed with error: \(error.localizedDescription)")
                }
                Mindbox.shared.refreshNotificationPermissionStatus()
            }
        }
    }
}
