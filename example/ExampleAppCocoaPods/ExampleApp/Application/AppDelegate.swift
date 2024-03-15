//
//  AppDelegate.swift
//  ExampleApp
//
//  Created by Sergei Semko on 3/11/24.
//

import UIKit
import Mindbox

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        UNUserNotificationCenter.current().delegate = self
        
        initMindbox()
        
        #if DEBUG
            Mindbox.logger.logLevel = .debug
        #endif
        
        // https://developers.mindbox.ru/docs/ios-setup-background-tasks-advanced#регистрация-фоновых-задач
        Mindbox.shared.registerBGTasks()
        
        // https://developers.mindbox.ru/docs/ios-app-start-tracking-advanced
        Mindbox.shared.track(.launch(launchOptions))
        
        registerForRemoteNotifications()
        
        return true
    }
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        /// https://developers.mindbox.ru/docs/ios-send-push-notifications-advanced#4-передать-в-sdk-apns-токен
        Mindbox.shared.apnsTokenUpdate(deviceToken: deviceToken)
        
        let deviceToken: String = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        Mindbox.logger.log(level: .info, message: "DeviceToken: \(deviceToken)")
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: any Error
    ) {
        Mindbox.logger.log(
            level: .fault,
            message: "Fail to register for remote notifications with error: \(error.localizedDescription)"
        )
    }
    
    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([any UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        
        // https://developers.mindbox.ru/docs/ios-app-start-tracking-advanced
        Mindbox.shared.track(.universalLink(userActivity))
        
        return true
    }
    
    // https://developers.mindbox.ru/docs/ios-sdk-initialization
    private func initMindbox() {
        
        let plistReader: PlistReader = EAPlistReader.shared
        let endpoint = plistReader.endpoint
        let domain = plistReader.domain
        
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
    
    // https://developers.mindbox.ru/docs/ios-send-push-notifications-advanced#3-реализовать-отображение-стандартных-уведомлений
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
        
        // https://developers.mindbox.ru/docs/ios-get-click-advanced#1-передача-кликов-по-push-уведомлениям
        Mindbox.shared.pushClicked(response: response)
        
        // https://developers.mindbox.ru/docs/ios-app-start-tracking-advanced
        Mindbox.shared.track(.push(response))
        
        let userInfo = response.notification.request.content.userInfo
        if let pushModel = Mindbox.shared.getMindboxPushData(userInfo: userInfo),
           Mindbox.shared.isMindboxPush(userInfo: userInfo) {
            
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
        }
        
        completionHandler()
    }
    
    private func openUrl(_ url: URL?) {
        guard let url else {
            Mindbox.logger.log(
                level: .debug,
                message: "Couldn't open the page. Url is empty."
            )
            return
        }
        
        UIApplication.shared.open(url)
    }
    
    // Handling notifcations
    // https://developers.mindbox.ru/docs/ios-send-push-notifications-advanced#2-запросить-разрешение-на-отображение-уведомлений
    private func registerForRemoteNotifications() {
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
        
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                Mindbox.logger.log(level: .info, message: "Permission granted \(granted)")
                if let error {
                    Mindbox.logger.log(
                        level: .error,
                        message: "NotificationsRequestAuthorization failed with error: \(error.localizedDescription)"
                    )
                }
                
                Mindbox.shared.notificationsRequestAuthorization(granted: granted)
            }
    }
}
