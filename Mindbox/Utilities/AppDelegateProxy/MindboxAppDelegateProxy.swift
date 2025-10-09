//
//  MindboxAppDelegateProxy.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 09.10.2025.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import UIKit

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
internal final class MindboxAppDelegateProxy: NSObject {

    private static var originalIMPs: [Selector: IMP] = [:]
    private static var addedBySDK: [Selector: Bool] = [:]
    private static var hasInstalledSwizzles = false
    private static let swizzleLock = NSObject()

    // MARK: - Public entry
    internal static func configure() {
        guard !hasInstalledSwizzles else {
            print("[Mindbox] ⚠️ Swizzling already installed — skipping")
            return
        }
        hasInstalledSwizzles = true

        guard !isRunningInExtension else {
            print("[Mindbox] ℹ️ Running in NSE — skipping AppDelegate swizzling")
            return
        }

        guard let delegate = UIApplication.shared.delegate else {
            print("[Mindbox] ❌ UIApplication.shared.delegate not found")
            return
        }

        let targetClass = type(of: delegate)
        print("[Mindbox] 🧩 Installing swizzles on \(targetClass)")

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

        if let unDelegate = UNUserNotificationCenter.current().delegate {
            let unClass = type(of: unDelegate)
            safeSwizzle(unClass,
                        original: AppDelegateSelector.willPresent,
                        swizzled: #selector(mb_userNotificationCenter(_:willPresent:withCompletionHandler:)))

            safeSwizzle(unClass,
                        original: AppDelegateSelector.didReceiveNotificationResponse,
                        swizzled: #selector(mb_userNotificationCenter(_:didReceive:withCompletionHandler:)))
        }

        print("[Mindbox] ✅ All swizzles successfully installed")
    }

    private static var isRunningInExtension: Bool {
        Bundle.main.bundlePath.hasSuffix(".appex")
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
                print("[Mindbox] 🧱 Added missing method: \(NSStringFromSelector(original))")
                addedBySDK[original] = true
                method = class_getInstanceMethod(targetClass, original)
            } else {
                print("[Mindbox] ⚠️ No method or default IMP for \(NSStringFromSelector(original)) — skipping")
                return
            }
        }

        guard
            let originalMethod = method,
            let swizzledMethod = class_getInstanceMethod(Self.self, swizzled),
            let origEncoding = method_getTypeEncoding(originalMethod),
            let swizEncoding = method_getTypeEncoding(swizzledMethod)
        else {
            print("[Mindbox] ⚠️ Cannot read type encodings — skipping \(NSStringFromSelector(original))")
            return
        }

        if strcmp(origEncoding, swizEncoding) != 0 {
            print("[Mindbox] ⚠️ Type mismatch for \(NSStringFromSelector(original)) — skipping swizzle")
            return
        }

        guard originalIMPs[original] == nil else {
            print("[Mindbox] ⚠️ Method already swizzled: \(NSStringFromSelector(original))")
            return
        }

        originalIMPs[original] = method_getImplementation(originalMethod)
        method_exchangeImplementations(originalMethod, swizzledMethod)
        print("[Mindbox] 🔄 Swizzled \(NSStringFromSelector(original))")
    }

    // MARK: - Default implementations
    private static func defaultIMP(for selector: Selector) -> IMP? {
        switch selector {
        case AppDelegateSelector.didRegisterForRemoteNotifications:
            let block: @convention(block) (Any, UIApplication, Data) -> Void = { _, _, _ in
                print("[Mindbox] 🧱 Default: didRegisterForRemoteNotificationsWithDeviceToken")
            }
            return imp_implementationWithBlock(block)

        case AppDelegateSelector.didFailToRegisterForRemoteNotifications:
            let block: @convention(block) (Any, UIApplication, Error) -> Void = { _, _, _ in
                print("[Mindbox] 🧱 Default: didFailToRegisterForRemoteNotificationsWithError")
            }
            return imp_implementationWithBlock(block)

        case AppDelegateSelector.performFetch:
            let block: @convention(block) (Any, UIApplication, @escaping (UIBackgroundFetchResult) -> Void) -> Void = { _, _, completion in
                print("[Mindbox] 🧱 Default: performFetchWithCompletionHandler")
                completion(.noData)
            }
            return imp_implementationWithBlock(block)

        case AppDelegateSelector.didReceiveRemoteNotification:
            let block: @convention(block) (Any, UIApplication, [AnyHashable: Any], @escaping (UIBackgroundFetchResult) -> Void) -> Void = { _, _, _, completion in
                print("[Mindbox] 🧱 Default: didReceiveRemoteNotification")
                completion(.noData)
            }
            return imp_implementationWithBlock(block)

        case AppDelegateSelector.willPresent:
            let block: @convention(block) (Any, UNUserNotificationCenter, UNNotification, @escaping (UNNotificationPresentationOptions) -> Void) -> Void = { _, _, notification, completion in
                print("[Mindbox] 🧱 Default: willPresent \(notification.request.identifier)")
                if #available(iOS 14.0, *) {
                    completion([.banner, .sound, .badge, .list])
                } else {
                    completion([.alert, .sound, .badge])
                }
            }
            return imp_implementationWithBlock(block)

        case AppDelegateSelector.didReceiveNotificationResponse:
            let block: @convention(block) (Any, UNUserNotificationCenter, UNNotificationResponse, @escaping () -> Void) -> Void = { _, _, response, completion in
                print("[Mindbox] 🧱 Default: didReceive response \(response.notification.request.identifier)")
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
        print("[Mindbox] 🧩 didRegisterForRemoteNotificationsWithDeviceToken")
        Mindbox.shared.apnsTokenUpdate(deviceToken: deviceToken)
        let selector = AppDelegateSelector.didRegisterForRemoteNotifications
        guard Self.addedBySDK[selector] != true else {
            return
        }
        if let imp = Self.originalIMPs[selector] {
            typealias Original = @convention(c) (Any, Selector, UIApplication, Data) -> Void
            unsafeBitCast(imp, to: Original.self)(self, selector, application, deviceToken)
        }
    }

    @objc
    func mb_application(_ application: UIApplication,
                        didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("[Mindbox] 🧩 didFailToRegisterForRemoteNotificationsWithError")
        let selector = AppDelegateSelector.didFailToRegisterForRemoteNotifications
        guard Self.addedBySDK[selector] != true else {
            return
        }
        if let imp = Self.originalIMPs[selector] {
            typealias Original = @convention(c) (Any, Selector, UIApplication, Error) -> Void
            unsafeBitCast(imp, to: Original.self)(self, selector, application, error)
        }
    }

    @objc
    func mb_application(_ application: UIApplication,
                        performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("[Mindbox] 🧩 performFetchWithCompletionHandler")
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
        print("[Mindbox] 🧩 didReceiveRemoteNotification")
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
        print("[Mindbox] 🧩 willPresent \(notification.request.identifier)")
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
        print("[Mindbox] 🧩 didReceive response \(response.notification.request.identifier)")
        let selector = AppDelegateSelector.didReceiveNotificationResponse
        Mindbox.shared.pushClicked(response: response)
        Mindbox.shared.track(.push(response))
        guard Self.addedBySDK[selector] != true else { completionHandler(); return }
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
