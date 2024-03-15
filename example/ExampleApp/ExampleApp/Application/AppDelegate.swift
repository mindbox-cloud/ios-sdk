//
//  AppDelegate.swift
//  ExampleApp
//
//  Created by Sergei Semko on 3/11/24.
//

import UIKit
import Mindbox
import OSLog

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        setUpDelegates()
        initMindbox()
        setUpMindboxLogger()
        Mindbox.shared.track(.launch(launchOptions))
        
        registerForRemoteNotifications()
        return true
    }
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Mindbox.shared.apnsTokenUpdate(deviceToken: deviceToken)
        
        let deviceToken: String = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        Logger.pushNotifications.log("DeviceToken: \(deviceToken)")
        UIPasteboard.general.string = deviceToken
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: any Error
    ) {
        Logger.pushNotifications.critical(
            "Fail to register for remote notifications with error: \(error.localizedDescription)"
        )
    }
    
    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([any UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        Mindbox.shared.track(.universalLink(userActivity))
        return true
    }
    
    private func initMindbox() {
        DispatchQueue.global().async {
            let plistReader: PlistReader = EAPlistReader.shared
            let endpoint = plistReader.endpoint
            let domain = plistReader.domain
            
            DispatchQueue.main.sync {
                do {
                    let mindboxSdkConfiguration = try MBConfiguration(
                        endpoint: endpoint,
                        domain: domain,
                        subscribeCustomerIfCreated: true,
                        shouldCreateCustomer: true
                    )
                    
                    Mindbox.shared.initialization(configuration: mindboxSdkConfiguration)
                } catch {
                    Mindbox.logger.log(level: .error, message: "\(error.localizedDescription)")
                }
            }
        }
    }
    
    private func setUpDelegates() {
        UNUserNotificationCenter.current().delegate = self
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

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let notificationPresentationsOptions: UNNotificationPresentationOptions = [.banner, .list, .badge, .sound]
        completionHandler(notificationPresentationsOptions)
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Mindbox.shared.pushClicked(response: response)
        Mindbox.shared.track(.push(response))
        
        let userInfo = response.notification.request.content.userInfo
        guard let pushModel = Mindbox.shared.getMindboxPushData(userInfo: userInfo),
                Mindbox.shared.isMindboxPush(userInfo: userInfo) else {
            return
        }
        
        var url: URL? = URL(string: "")
        if let buttons = pushModel.buttons,
           let clickedButton = buttons.first(where: { $0.uniqueKey == response.actionIdentifier }),
           let buttonStringUrl = clickedButton.url,
           let buttonUrl = URL(string: buttonStringUrl) {
            url = buttonUrl
        } else if
            let clickStringUrl = pushModel.clickUrl,
            let clickUrl = URL(string: clickStringUrl) {
            url = clickUrl
        }
        
        if let payload = pushModel.payload {
            Mindbox.logger.log(level: .debug, message: payload)
        }
        
        openUrl(url)
        
        completionHandler()
    }
    
    private func openUrl(_ url: URL?) {
        guard let url else {
            Logger.pushNotifications.log("Couldn't open the page. Url is empty.")
            return
        }
        
        UIApplication.shared.open(url)
    }
    
    private func setUpMindboxLogger() {
        Mindbox.logger.logLevel = .default
    }
    
    // Handling notifcations
    private func registerForRemoteNotifications() {
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
        
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                Logger.pushNotifications.log("Permission granted \(granted)")
                if let error {
                    Logger.pushNotifications.error(
                        "NotificationsRequestAuthorization failed with error: \(error.localizedDescription)"
                    )
                }
                
                Mindbox.shared.notificationsRequestAuthorization(granted: granted)
            }
    }
}
