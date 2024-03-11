//
//  AppDelegate.swift
//  ExampleApp
//
//  Created by Sergei Semko on 3/11/24.
//

import UIKit
import Mindbox

@main
final class AppDelegate: MindboxAppDelegate {

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Call super when using MindboxAppDelegate
        super.application(application, didFinishLaunchingWithOptions: launchOptions)
        
        registerForRemoteNotifications()
        
        do {
            let mindboxSdkConfiguration = try MBConfiguration(
                endpoint: "Mpush-test.ExampleCocoaPods.IosApp",
                domain: "api.mindbox.ru",
                subscribeCustomerIfCreated: true,
                shouldCreateCustomer: true
            )
            
            Mindbox.shared.initialization(configuration: mindboxSdkConfiguration)
        } catch {
            print(error)
        }
        
        return true
    }
    
    private func registerForRemoteNotifications() {
        UNUserNotificationCenter.current().delegate = self
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
            UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                print("Permission granted \(granted)")
                if let error {
                    print("NotificationsRequestAuthorization failed with error: \(error.localizedDescription)")
                }
                Mindbox.shared.notificationsRequestAuthorization(granted: granted)
            }
        }
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // TODO: Check `.list` instead `.alert`
        completionHandler([.alert, .badge, .sound])
    }

    // MARK: UISceneSession Lifecycle

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
    }
}


