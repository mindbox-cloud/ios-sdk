//
//  MindboxAppDelegate.swift
//  Mindbox
//
//  Created by Ihor Kandaurov on 07.05.2021.
//

import UIKit

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
}
