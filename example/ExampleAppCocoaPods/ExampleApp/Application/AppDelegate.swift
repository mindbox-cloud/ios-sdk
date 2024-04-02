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
    
    private let logManager = EALogManager.shared
    
    func application(
        _ application: UIApplication,
        willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool
    {
        logManager.log(#function)
        return true
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        logManager.log("Start \(#function)")
        logManager.log("isProtectedDataAvailable before initMindbox: \(UIApplication.shared.isProtectedDataAvailable)")
        logManager.logUserDefaultsMindbox()
        
        UNUserNotificationCenter.current().delegate = self
        
        initMindbox()
        logManager.log("isProtectedDataAvailable after initMindbox: \(UIApplication.shared.isProtectedDataAvailable)")
        
        #if DEBUG
        // https://developers.mindbox.ru/docs/ios-sdk-methods#управление-логированием
//            Mindbox.logger.logLevel = .debug
        #endif
        
        registerBackgroundTasks()
        
        // https://developers.mindbox.ru/docs/ios-app-start-tracking-advanced
        Mindbox.shared.track(.launch(launchOptions))
        
        registerForRemoteNotifications()
        
        defer {
            logManager.log("End of \(#function)")
        }
        return true
    }
    
    func applicationProtectedDataDidBecomeAvailable(_ application: UIApplication) {
        logManager.log(#function)
        logManager.log("isProtectedDataAvailable: \(UIApplication.shared.isProtectedDataAvailable)")
        logManager.logUserDefaultsMindbox()
        logManager.log("End of \(#function)")
    }
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        /// https://developers.mindbox.ru/docs/ios-send-push-notifications-advanced#4-передать-в-sdk-apns-токен
        Mindbox.shared.apnsTokenUpdate(deviceToken: deviceToken)
        logManager.log(#function)
        
        let deviceToken: String = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        Mindbox.logger.log(level: .info, message: "DeviceToken: \(deviceToken)")
        
        logManager.log("DeviceToken: \(deviceToken)")
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: any Error
    ) {
        // https://developers.mindbox.ru/docs/ios-sdk-methods#mindboxloggerlog
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
    
    func application(
        _ application: UIApplication,
        performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        // https://developers.mindbox.ru/docs/ios-setup-background-tasks-advanced#регистрация-фоновых-задач
        Mindbox.shared.application(
            application,
            performFetchWithCompletionHandler: completionHandler
        )
    }
    
    
    // MARK: Private methods
    
    // https://developers.mindbox.ru/docs/ios-sdk-initialization
    private func initMindbox() {
        
        logManager.log("Start \(#function)")
        
        let endpoint = "Mpush-test.ExampleCocoaPods.IosApp"
        let domain = "api.mindbox.ru"
        
        do {
            // https://developers.mindbox.ru/docs/ios-sdk-initialization#2-выбор-варианта-конфигурации-sdk
            let mindboxSdkConfiguration = try MBConfiguration(
                endpoint: endpoint,
                domain: domain,
                subscribeCustomerIfCreated: true,
                shouldCreateCustomer: true
            )
            
            // https://developers.mindbox.ru/docs/ios-sdk-initialization#3-инициализация-sdk
            Mindbox.shared.initialization(configuration: mindboxSdkConfiguration)
        } catch {
            logManager.log("Mindbox init failed: \(error.localizedDescription)")
            Mindbox.logger.log(level: .error, message: "\(error.localizedDescription)")
        }
        
        logManager.log("End \(#function)")
    }
    
    private func registerBackgroundTasks() {
        // https://developers.mindbox.ru/docs/ios-setup-background-tasks-advanced#регистрация-фоновых-задач
        if #available(iOS 13.0, *) {
            Mindbox.shared.registerBGTasks()
        } else {
            UIApplication.shared.setMinimumBackgroundFetchInterval(
                UIApplication.backgroundFetchIntervalMinimum
            )
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
            
//            openUrlInBrowser(url)
        }
        
        NotificationCenter.default.post(
            name: Notification.Name(Constants.notificationCenterName),
            object: nil,
            userInfo: userInfo
        )
        
        completionHandler()
    }
    
    
    // MARK: Private Methods
    
    private func openUrlInBrowser(_ url: URL?) {
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
