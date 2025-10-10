//
//  MindboxAppDelegateProxy.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 09.10.2025.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import UIKit
import MindboxLogger

@available(iOS 11.0, *)
internal enum AppDelegateSelector {
    static let didRegisterForRemoteNotifications =
        #selector(UIApplicationDelegate.application(_:didRegisterForRemoteNotificationsWithDeviceToken:))
    static let didFailToRegisterForRemoteNotifications =
        #selector(UIApplicationDelegate.application(_:didFailToRegisterForRemoteNotificationsWithError:))
    static let didReceiveRemoteNotification =
        #selector(UIApplicationDelegate.application(_:didReceiveRemoteNotification:fetchCompletionHandler:))
    static let performFetch =
        #selector(UIApplicationDelegate.application(_:performFetchWithCompletionHandler:))
    static let willPresent =
        #selector(UNUserNotificationCenterDelegate.userNotificationCenter(_:willPresent:withCompletionHandler:))
    static let didReceiveNotificationResponse =
        #selector(UNUserNotificationCenterDelegate.userNotificationCenter(_:didReceive:withCompletionHandler:))
}

@available(iOS 11.0, *)
internal final class MindboxAppDelegateProxy: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    static let shared = MindboxAppDelegateProxy()
    
    private static var originalIMPs: [Selector: IMP] = [:]
    private static var addedBySDK: [Selector: Bool] = [:]
    private static var hasInstalledSwizzles = false
    private static let swizzleLock = NSObject()

    // MARK: - Public entry
    internal static func configure() {
        guard !hasInstalledSwizzles else {
            Logger.common(message: "[MindboxAppDelegateProxy] [Lifecycle] Swizzling already installed — skipping", level: .debug, category: .appDelegate)
            return
        }
        hasInstalledSwizzles = true

        guard !isRunningInExtension else {
            Logger.common(message: "[MindboxAppDelegateProxy] [Lifecycle] Running in NSE — skipping AppDelegate swizzling",
                          level: .debug, category: .appDelegate)
            return
        }

        guard let delegate = UIApplication.shared.delegate else {
            Logger.common(message: "[MindboxAppDelegateProxy] [Error] UIApplication.shared.delegate not found",
                          level: .error, category: .appDelegate)
            return
        }

        let targetClass = type(of: delegate)
        Logger.common(message: "[MindboxAppDelegateProxy] [Lifecycle] Installing swizzles on \(targetClass)",
                      level: .debug, category: .appDelegate)

        safeSwizzle(targetClass,
                    original: AppDelegateSelector.didRegisterForRemoteNotifications,
                    swizzled: #selector(mb_application(_:didRegisterForRemoteNotificationsWithDeviceToken:)))

        safeSwizzle(targetClass,
                    original: AppDelegateSelector.didFailToRegisterForRemoteNotifications,
                    swizzled: #selector(mb_application(_:didFailToRegisterForRemoteNotificationsWithError:)))

        safeSwizzle(targetClass,
                    original: AppDelegateSelector.performFetch,
                    swizzled: #selector(mb_application(_:performFetchWithCompletionHandler:)))

        safeSwizzle(targetClass,
                    original: AppDelegateSelector.didReceiveRemoteNotification,
                    swizzled: #selector(mb_application(_:didReceiveRemoteNotification:fetchCompletionHandler:)))
        
        setupUserNotificationCenterSwizzling()

        Logger.common(message: "[MindboxAppDelegateProxy] [Lifecycle] All swizzles successfully installed",
                      level: .debug, category: .appDelegate)
    }

    private static var isRunningInExtension: Bool {
        Bundle.main.bundlePath.hasSuffix(".appex")
    }
    
    private static func setupUserNotificationCenterSwizzling() {
        let center = UNUserNotificationCenter.current()
        let delegateToSwizzle: AnyObject

        if let existing = center.delegate {
            delegateToSwizzle = existing
            Logger.common(message: "[MindboxAppDelegateProxy] [Lifecycle] Existing UNUserNotificationCenter delegate detected — swizzling applied",
                          level: .debug, category: .appDelegate)
        } else {
            center.delegate = shared
            delegateToSwizzle = shared
            Logger.common(message: "[MindboxAppDelegateProxy] [Lifecycle] No UNUserNotificationCenter delegate found — Mindbox set as delegate",
                          level: .debug, category: .appDelegate)
        }

        let targetClass: any AnyObject.Type = type(of: delegateToSwizzle)

        [
            (AppDelegateSelector.willPresent,
             #selector(mb_userNotificationCenter(_:willPresent:withCompletionHandler:))),
            (AppDelegateSelector.didReceiveNotificationResponse,
             #selector(mb_userNotificationCenter(_:didReceive:withCompletionHandler:)))
        ].forEach { original, swizzled in
            safeSwizzle(targetClass, original: original, swizzled: swizzled)
        }
    }

    // MARK: - Safe Swizzler
    private static func safeSwizzle(_ targetClass: AnyClass, original: Selector, swizzled: Selector) {
        objc_sync_enter(swizzleLock)
        defer { objc_sync_exit(swizzleLock) }

        var method = class_getInstanceMethod(targetClass, original)

        if method == nil {
            if let swizzledMethod = class_getInstanceMethod(Self.self, swizzled),
               let types = method_getTypeEncoding(swizzledMethod),
               let blockIMP = defaultIMP(for: original),
               class_addMethod(targetClass, original, blockIMP, types) {
                Logger.common(message: "[MindboxAppDelegateProxy] [Swizzle] Added missing method: \(NSStringFromSelector(original))",
                              level: .debug, category: .appDelegate)
                addedBySDK[original] = true
                method = class_getInstanceMethod(targetClass, original)
            } else {
                Logger.common(message: "[MindboxAppDelegateProxy] [Error] No method or default IMP for \(NSStringFromSelector(original)) — skipping",
                              level: .error, category: .appDelegate)
                return
            }
        }

        guard
            let originalMethod = method,
            let swizzledMethod = class_getInstanceMethod(Self.self, swizzled),
            let origEncoding = method_getTypeEncoding(originalMethod),
            let swizEncoding = method_getTypeEncoding(swizzledMethod)
        else {
            Logger.common(message: "[MindboxAppDelegateProxy] [Error] Cannot read type encodings — skipping \(NSStringFromSelector(original))",
                          level: .error, category: .appDelegate)
            return
        }

        if strcmp(origEncoding, swizEncoding) != 0 {
            Logger.common(message: "[MindboxAppDelegateProxy] [Error] Type mismatch for \(NSStringFromSelector(original)) — skipping swizzle",
                          level: .error, category: .appDelegate)
            return
        }

        guard originalIMPs[original] == nil else {
            Logger.common(message: "[MindboxAppDelegateProxy] [Swizzle] Method already swizzled: \(NSStringFromSelector(original))",
                          level: .debug, category: .appDelegate)
            return
        }

        originalIMPs[original] = method_getImplementation(originalMethod)
        method_exchangeImplementations(originalMethod, swizzledMethod)
        Logger.common(message: "[MindboxAppDelegateProxy] [Swizzle] Swizzled \(NSStringFromSelector(original))",
                      level: .debug, category: .appDelegate)
    }

    // MARK: - Default implementations
    private static func defaultIMP(for selector: Selector) -> IMP? {
        switch selector {
        case AppDelegateSelector.didRegisterForRemoteNotifications:
            let block: @convention(block) (Any, UIApplication, Data) -> Void = { _, _, _ in
                Logger.common(message: "[MindboxAppDelegateProxy] [Default] didRegisterForRemoteNotificationsWithDeviceToken",
                              level: .debug, category: .appDelegate)
            }
            return imp_implementationWithBlock(block)

        case AppDelegateSelector.didFailToRegisterForRemoteNotifications:
            let block: @convention(block) (Any, UIApplication, Error) -> Void = { _, _, _ in
                Logger.common(message: "[MindboxAppDelegateProxy] [Default] didFailToRegisterForRemoteNotificationsWithError",
                              level: .debug, category: .appDelegate)
            }
            return imp_implementationWithBlock(block)

        case AppDelegateSelector.performFetch:
            let block: @convention(block) (Any, UIApplication, @escaping (UIBackgroundFetchResult) -> Void) -> Void = { _, _, completion in
                Logger.common(message: "[MindboxAppDelegateProxy] [Default] performFetchWithCompletionHandler — no client implementation",
                              level: .debug, category: .appDelegate)
                completion(.noData)
            }
            return imp_implementationWithBlock(block)

        case AppDelegateSelector.didReceiveRemoteNotification:
            let block: @convention(block) (Any, UIApplication, [AnyHashable: Any], @escaping (UIBackgroundFetchResult) -> Void) -> Void = { _, _, _, completion in
                Logger.common(message: "[MindboxAppDelegateProxy] [Default] didReceiveRemoteNotification — handled internally",
                              level: .debug, category: .appDelegate)
                completion(.noData)
            }
            return imp_implementationWithBlock(block)

        case AppDelegateSelector.willPresent:
            let block: @convention(block) (Any, UNUserNotificationCenter, UNNotification, @escaping (UNNotificationPresentationOptions) -> Void) -> Void = { _, _, notification, completion in
                Logger.common(message: "[MindboxAppDelegateProxy] [Default] willPresent notification: \(notification.request.identifier)",
                              level: .debug, category: .appDelegate)
                if #available(iOS 14.0, *) {
                    completion([.banner, .sound, .badge, .list])
                } else {
                    completion([.alert, .sound, .badge])
                }
            }
            return imp_implementationWithBlock(block)

        case AppDelegateSelector.didReceiveNotificationResponse:
            let block: @convention(block) (Any, UNUserNotificationCenter, UNNotificationResponse, @escaping () -> Void) -> Void = { _, _, response, completion in
                Logger.common(message: "[MindboxAppDelegateProxy] [Default] didReceive notification response: \(response.notification.request.identifier)",
                              level: .debug, category: .appDelegate)
                completion()
            }
            return imp_implementationWithBlock(block)

        default:
            return nil
        }
    }
}

// MARK: - UIApplicationDelegate hooks
@available(iOS 11.0, *)
extension MindboxAppDelegateProxy {

    @objc
    func mb_application(_ application: UIApplication,
                        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Logger.common(message: "[MindboxAppDelegateProxy] [Delegate] didRegisterForRemoteNotificationsWithDeviceToken",
                      level: .debug, category: .appDelegate)
        Mindbox.shared.apnsTokenUpdate(deviceToken: deviceToken)
        let selector = AppDelegateSelector.didRegisterForRemoteNotifications
        guard Self.addedBySDK[selector] != true else { return }
        if let imp = Self.originalIMPs[selector] {
            typealias Original = @convention(c) (Any, Selector, UIApplication, Data) -> Void
            unsafeBitCast(imp, to: Original.self)(self, selector, application, deviceToken)
        }
    }

    @objc
    func mb_application(_ application: UIApplication,
                        didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Logger.common(message: "[MindboxAppDelegateProxy] [Delegate] didFailToRegisterForRemoteNotificationsWithError: \(error.localizedDescription)",
                      level: .error, category: .appDelegate)
        let selector = AppDelegateSelector.didFailToRegisterForRemoteNotifications
        guard Self.addedBySDK[selector] != true else { return }
        if let imp = Self.originalIMPs[selector] {
            typealias Original = @convention(c) (Any, Selector, UIApplication, Error) -> Void
            unsafeBitCast(imp, to: Original.self)(self, selector, application, error)
        }
    }

    @objc
    func mb_application(_ application: UIApplication,
                        performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        Logger.common(message: "[MindboxAppDelegateProxy] [Delegate] performFetchWithCompletionHandler",
                      level: .debug, category: .appDelegate)
        let selector = AppDelegateSelector.performFetch
        guard Self.addedBySDK[selector] != true else {
            Mindbox.shared.application(application, performFetchWithCompletionHandler: completionHandler)
            return
        }
        if let imp = Self.originalIMPs[selector] {
            typealias Original = @convention(c) (Any, Selector, UIApplication, @escaping (UIBackgroundFetchResult) -> Void) -> Void
            unsafeBitCast(imp, to: Original.self)(self, selector, application, completionHandler)
        } else {
            Mindbox.shared.application(application, performFetchWithCompletionHandler: completionHandler)
        }
    }

    @objc
    func mb_application(_ application: UIApplication,
                        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        Logger.common(message: "[MindboxAppDelegateProxy] [Delegate] didReceiveRemoteNotification",
                      level: .debug, category: .appDelegate)
        let selector = AppDelegateSelector.didReceiveRemoteNotification
        guard Self.addedBySDK[selector] != true else {
            Mindbox.shared.application(application, performFetchWithCompletionHandler: completionHandler)
            return
        }
        if let imp = Self.originalIMPs[selector] {
            typealias Original = @convention(c)
                (Any, Selector, UIApplication, [AnyHashable: Any], @escaping (UIBackgroundFetchResult) -> Void) -> Void
            unsafeBitCast(imp, to: Original.self)(self, selector, application, userInfo, completionHandler)
        } else {
            Mindbox.shared.application(application, performFetchWithCompletionHandler: completionHandler)
        }
    }

    @objc
    func mb_userNotificationCenter(_ center: UNUserNotificationCenter,
                                   willPresent notification: UNNotification,
                                   withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        Logger.common(message: "[MindboxAppDelegateProxy] [Delegate] willPresent notification: \(notification.request.identifier)",
                      level: .debug, category: .appDelegate)
        let selector = AppDelegateSelector.willPresent
        guard Self.addedBySDK[selector] != true else {
            notificationPresentation(completionHandler)
            return
        }
        if let imp = Self.originalIMPs[selector] {
            typealias Original = @convention(c)
                (Any, Selector, UNUserNotificationCenter, UNNotification, @escaping (UNNotificationPresentationOptions) -> Void) -> Void
            unsafeBitCast(imp, to: Original.self)(self, selector, center, notification, completionHandler)
        } else {
            notificationPresentation(completionHandler)
        }
    }

    @objc
    func mb_userNotificationCenter(_ center: UNUserNotificationCenter,
                                   didReceive response: UNNotificationResponse,
                                   withCompletionHandler completionHandler: @escaping () -> Void) {
        Logger.common(message: "[MindboxAppDelegateProxy] [Delegate] didReceive notification response: \(response.notification.request.identifier)",
                      level: .debug, category: .appDelegate)
        let selector = AppDelegateSelector.didReceiveNotificationResponse
        Mindbox.shared.pushClicked(response: response)
        Mindbox.shared.track(.push(response))
        guard Self.addedBySDK[selector] != true else {
            completionHandler()
            return
        }
        if let imp = Self.originalIMPs[selector] {
            typealias Original = @convention(c)
                (Any, Selector, UNUserNotificationCenter, UNNotificationResponse, @escaping () -> Void) -> Void
            unsafeBitCast(imp, to: Original.self)(self, selector, center, response, completionHandler)
        } else {
            completionHandler()
        }
    }

    private func notificationPresentation(_ completion: (UNNotificationPresentationOptions) -> Void) {
        if #available(iOS 14.0, *) {
            completion([.banner, .sound, .badge, .list])
        } else {
            completion([.alert, .sound, .badge])
        }
    }
}
