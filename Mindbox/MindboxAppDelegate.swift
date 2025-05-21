//
//  MindboxAppDelegate.swift
//  Mindbox
//
//  Created by Ihor Kandaurov on 07.05.2021.
//

import UIKit
import MindboxLogger

/** Mindbox's UIApplicationDelegate
 
When you override any methods, don't forget to call `super.` */
open class MindboxAppDelegate: NSObject, UNUserNotificationCenterDelegate, UIApplicationDelegate {
    @discardableResult
    open func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self

        if #available(iOS 13.0, *) {
            Mindbox.shared.registerBGTasks()
        }
        UIApplication.shared.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)

        Mindbox.shared.track(.launch(launchOptions))

        return true
    }

    open func application(
        _ application: UIApplication,
        performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        Mindbox.shared.application(application, performFetchWithCompletionHandler: completionHandler)
    }

    open func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        Mindbox.shared.track(.universalLink(userActivity))
        return true
    }

    open func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Mindbox.shared.apnsTokenUpdate(deviceToken: deviceToken)
    }
    
    open func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: any Error) {
        Logger.common(message: "didFailToRegisterForRemoteNotificationsWithError \(error.localizedDescription)",
                      level: .error, category: .notification)
    }

    open func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Mindbox.shared.pushClicked(response: response)
        Mindbox.shared.track(.push(response))
        completionHandler()
    }

    open func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        Mindbox.shared.application(application, performFetchWithCompletionHandler: completionHandler)
    }

    open func applicationWillEnterForeground(_ application: UIApplication) {
        Logger.common(message: "Enter foreground", level: .info, category: .general)
    }

    open func applicationDidEnterBackground(_ application: UIApplication) {
        Logger.common(message: "Enter background", level: .info, category: .general)
    }

    open func applicationWillTerminate(_ application: UIApplication) {
        Logger.common(message: "App is closed", level: .info, category: .general)
    }

    open func applicationDidBecomeActive(_ application: UIApplication) {
        Logger.common(message: "App is active", level: .info, category: .general)
    }
}
