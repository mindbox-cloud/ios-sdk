//
//  MindboxApp.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 08.10.2025.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import Foundation
import UIKit
import ObjectiveC.runtime

private enum AppDelegateSelector {
    static let didRegisterForRemoteNotifications =
        #selector(UIApplicationDelegate.application(_:didRegisterForRemoteNotificationsWithDeviceToken:))
    static let didFailToRegisterForRemoteNotifications =
        #selector(UIApplicationDelegate.application(_:didFailToRegisterForRemoteNotificationsWithError:))
    static let didReceiveRemoteNotification =
        #selector(UIApplicationDelegate.application(_:didReceiveRemoteNotification:fetchCompletionHandler:))
    static let performFetch =
        #selector(UIApplicationDelegate.application(_:performFetchWithCompletionHandler:))
    static let willPresent = #selector(UNUserNotificationCenterDelegate.userNotificationCenter(_:willPresent:withCompletionHandler:))
    static let didReceiveNotificationResponse =
          #selector(UNUserNotificationCenterDelegate.userNotificationCenter(_:didReceive:withCompletionHandler:))
}

final class MindboxAppDelegateProxy: NSObject {

    private static var originalIMPs: [Selector: IMP] = [:]
    private static var addedBySDK: [Selector: Bool] = [:]
    private static var hasInstalledSwizzles = false

    // MARK: - Public entry
    static func configure() {
        guard !hasInstalledSwizzles else {
            print("[TEST] ⚠️ Mindbox swizzling already installed — skipping duplicate configure()")
            return
        }
        hasInstalledSwizzles = true

        guard let delegate = UIApplication.shared.delegate else {
            print("[TEST] ❌ UIApplication.shared.delegate not found")
            return
        }

        let targetClass = type(of: delegate)
        print("[TEST] 🧩 Installing Mindbox swizzles on \(targetClass)")

        safeSwizzle(targetClass,
                    original: #selector(UIApplicationDelegate.application(_:didRegisterForRemoteNotificationsWithDeviceToken:)),
                    swizzled: #selector(mb_application(_:didRegisterForRemoteNotificationsWithDeviceToken:)))
      
        safeSwizzle(targetClass,
                    original: #selector(UIApplicationDelegate.application(_:didFailToRegisterForRemoteNotificationsWithError:)),
                    swizzled: #selector(mb_application(_:didFailToRegisterForRemoteNotificationsWithError:)))

        safeSwizzle(targetClass,
                    original: #selector(UIApplicationDelegate.application(_:performFetchWithCompletionHandler:)),
                    swizzled: #selector(mb_application(_:performFetchWithCompletionHandler:)))

        safeSwizzle(targetClass,
                    original: #selector(UIApplicationDelegate.application(_:didReceiveRemoteNotification:fetchCompletionHandler:)),
                    swizzled: #selector(mb_application(_:didReceiveRemoteNotification:fetchCompletionHandler:)))

        if let unDelegate = UNUserNotificationCenter.current().delegate {
            let unClass = type(of: unDelegate)
            safeSwizzle(unClass,
                        original: #selector(UNUserNotificationCenterDelegate.userNotificationCenter(_:willPresent:withCompletionHandler:)),
                        swizzled: #selector(mb_userNotificationCenter(_:willPresent:withCompletionHandler:)))
        }
      
        print("[TEST] ✅ All Mindbox swizzles successfully installed")
    }

    // MARK: - Safe Swizzler
  private static func safeSwizzle(_ targetClass: AnyClass, original: Selector, swizzled: Selector) {
      var method = class_getInstanceMethod(targetClass, original)

      if method == nil {
          if let swizzledMethod = class_getInstanceMethod(Self.self, swizzled),
             let types = method_getTypeEncoding(swizzledMethod) {

              let blockIMP: IMP

              switch NSStringFromSelector(original) {
              case "application:didRegisterForRemoteNotificationsWithDeviceToken:":
                  let block: @convention(block) (Any, UIApplication, Data) -> Void = { _, _, _ in
                      print("[TEST] 🧱 Default empty implementation for didRegisterForRemoteNotificationsWithDeviceToken")
                  }
                  blockIMP = imp_implementationWithBlock(block)

              case "application:didFailToRegisterForRemoteNotificationsWithError:":
                  let block: @convention(block) (Any, UIApplication, Error) -> Void = { _, _, _ in
                      print("[TEST] 🧱 Default empty implementation for didFailToRegisterForRemoteNotificationsWithError")
                  }
                  blockIMP = imp_implementationWithBlock(block)
              case "application:performFetchWithCompletionHandler:":
                  let block: @convention(block) (Any, UIApplication, @escaping (UIBackgroundFetchResult) -> Void) -> Void = { _, _, completion in
                      print("[TEST] 🧱 Default empty implementation for performFetchWithCompletionHandler")
                      completion(.noData)
                  }
                  blockIMP = imp_implementationWithBlock(block)

              case "application:didReceiveRemoteNotification:fetchCompletionHandler:":
                  let block: @convention(block) (Any, UIApplication, [AnyHashable: Any], @escaping (UIBackgroundFetchResult) -> Void) -> Void = { _, _, _, completion in
                      print("[TEST] 🧱 Default empty implementation for didReceiveRemoteNotification")
                      completion(.noData)
                  }
                  blockIMP = imp_implementationWithBlock(block)

              case "userNotificationCenter:willPresentNotification:withCompletionHandler:":
                  let block: @convention(block) (Any, UNUserNotificationCenter, UNNotification, @escaping (UNNotificationPresentationOptions) -> Void) -> Void = { _, _, notification, completion in
                      print("[TEST] 🧱 Default empty implementation for willPresent notification \(notification.request.identifier)")
                      if #available(iOS 14.0, *) {
                          completion([.banner, .sound, .badge, .list])
                      } else {
                          completion([.sound, .badge, .alert])
                      }
                  }
                  blockIMP = imp_implementationWithBlock(block)
              default:
                  let block: @convention(block) (Any) -> Void = { _ in
                      print("[TEST] 🧱 Default empty implementation for \(NSStringFromSelector(original))")
                  }
                  blockIMP = imp_implementationWithBlock(block)
              }

              if class_addMethod(targetClass, original, blockIMP, types) {
                  print("[TEST] 🧱 Added missing method: \(NSStringFromSelector(original))")
                  addedBySDK[original] = true
              }

              method = class_getInstanceMethod(targetClass, original)
          }
      }

      guard
          let originalMethod = method,
          let swizzledMethod = class_getInstanceMethod(Self.self, swizzled)
      else {
          print("[TEST] ⚠️ Cannot swizzle \(NSStringFromSelector(original)) — no method found or created")
          return
      }

      if originalIMPs[original] != nil {
          print("[TEST] ⚠️ Method already swizzled: \(NSStringFromSelector(original))")
          return
      }
    

      originalIMPs[original] = method_getImplementation(originalMethod)
      method_exchangeImplementations(originalMethod, swizzledMethod)

      print("[TEST] 🔄 Safe swizzled \(NSStringFromSelector(original)) on \(targetClass)")
  }
}

// MARK: - UIApplicationDelegate
extension MindboxAppDelegateProxy {
  
  @objc func mb_application(_ application: UIApplication,
                            didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
      print("[TEST] 🧩 SDK: didRegisterForRemoteNotificationsWithDeviceToken called")

      Mindbox.shared.apnsTokenUpdate(deviceToken: deviceToken)
      let selector = AppDelegateSelector.didRegisterForRemoteNotifications

      guard Self.addedBySDK[selector] != true else {
          print("[TEST] ✅ No client implementation detected — executing SDK logic only")
          return
      }

      if let imp = Self.originalIMPs[selector] {
          print("[TEST] ⚙️ Client implementation detected — calling original AppDelegate logic")
          typealias Original = @convention(c) (Any, Selector, UIApplication, Data) -> Void
          let original = unsafeBitCast(imp, to: Original.self)
          original(self, selector, application, deviceToken)
      }
  }

    @objc func mb_application(_ application: UIApplication,
                              didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("[TEST] 🧩 SDK: didFailToRegisterForRemoteNotificationsWithError called")
      
//        Logger.common(message: "didFailToRegisterForRemoteNotificationsWithError \(error)", level: .info, category: .general)
        let selector = AppDelegateSelector.didFailToRegisterForRemoteNotifications
        guard Self.addedBySDK[selector] != true else {
            print("[TEST] ✅ No client implementation detected — executing SDK logic only")
            return
        }
      
        if let imp = Self.originalIMPs[selector] {
            print("[TEST] ⚙️ Client implementation detected — calling original AppDelegate logic")
            typealias Original = @convention(c) (Any, Selector, UIApplication, Error) -> Void
            let original = unsafeBitCast(imp, to: Original.self)
            original(self, selector, application, error)
        }
    }

    @objc func mb_application(_ application: UIApplication,
                              performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("[TEST] 🧩 SDK: performFetchWithCompletionHandler called")

        let selector = AppDelegateSelector.performFetch
        guard Self.addedBySDK[selector] != true else {
            Mindbox.shared.application(application, performFetchWithCompletionHandler: completionHandler)
            print("[TEST] ✅ No client implementation detected — executing SDK logic only")
            return
        }

        if let imp = Self.originalIMPs[selector] {
            print("[TEST] ⚙️ Client implementation detected — calling original AppDelegate logic")
            typealias Original = @convention(c) (Any, Selector, UIApplication, @escaping (UIBackgroundFetchResult) -> Void) -> Void
            let original = unsafeBitCast(imp, to: Original.self)
            original(self, selector, application, completionHandler)
        } else {
            Mindbox.shared.application(application, performFetchWithCompletionHandler: completionHandler)
        }
    }

    @objc func mb_application(_ application: UIApplication,
                              didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                              fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("[TEST] 🧩 SDK: didReceiveRemoteNotification called")
      // Не проверили.
        let selector = AppDelegateSelector.didReceiveRemoteNotification

        guard Self.addedBySDK[selector] != true else {
            Mindbox.shared.application(application, performFetchWithCompletionHandler: completionHandler)
            print("[TEST] ✅ No client implementation detected — executing SDK logic only")
            return
        }

        if let imp = Self.originalIMPs[selector] {
            print("[TEST] ⚙️ Client implementation detected — calling original AppDelegate logic")
            typealias Original = @convention(c)
                (Any, Selector, UIApplication, [AnyHashable: Any],
                 @escaping (UIBackgroundFetchResult) -> Void) -> Void
            let original = unsafeBitCast(imp, to: Original.self)
            original(self, selector, application, userInfo, completionHandler)
        } else {
            Mindbox.shared.application(application, performFetchWithCompletionHandler: completionHandler)
        }
    }

    @objc func mb_userNotificationCenter(_ center: UNUserNotificationCenter,
                                         willPresent notification: UNNotification,
                                         withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("[TEST] 🧩 SDK: willPresent notification \(notification.request.identifier)")

        let selector = AppDelegateSelector.willPresent

        guard Self.addedBySDK[selector] != true else {
            print("[TEST] ✅ No client implementation detected — executing SDK logic only")
            notificationPresentation(completionHandler)
            return
        }

        if let imp = Self.originalIMPs[selector] {
            print("[TEST] ⚙️ Client implementation detected — calling original UNUserNotificationCenter delegate logic")
            typealias Original = @convention(c)
                (Any, Selector, UNUserNotificationCenter, UNNotification,
                 @escaping (UNNotificationPresentationOptions) -> Void) -> Void
            let original = unsafeBitCast(imp, to: Original.self)
            original(self, selector, center, notification, completionHandler)
        } else {
            notificationPresentation(completionHandler)
        }
    }

    @objc func mb_userNotificationCenter(_ center: UNUserNotificationCenter,
                                         didReceive response: UNNotificationResponse,
                                         withCompletionHandler completionHandler: @escaping () -> Void) {
        print("[TEST] 🧩 SDK: didReceive notification response \(response.notification.request.identifier)")

        let selector = AppDelegateSelector.didReceiveNotificationResponse
      
        Mindbox.shared.pushClicked(response: response)
        Mindbox.shared.track(.push(response))

        guard Self.addedBySDK[selector] != true else {
            print("[TEST] ✅ No client implementation detected — executing SDK logic only")
            completionHandler()
            return
        }

        if let imp = Self.originalIMPs[selector] {
            print("[TEST] ⚙️ Client implementation detected — calling original UNUserNotificationCenter delegate logic")
            typealias Original = @convention(c)
                (Any, Selector, UNUserNotificationCenter, UNNotificationResponse,
                 @escaping () -> Void) -> Void
            let original = unsafeBitCast(imp, to: Original.self)
            original(self, selector, center, response, completionHandler)
        } else {
            completionHandler()
        }
    }
}

extension MindboxAppDelegateProxy {
    private func notificationPresentation(_ completion: (UNNotificationPresentationOptions) -> Void) {
        if #available(iOS 14.0, *) {
            completion([.banner, .sound, .badge, .list])
        } else {
            completion([.sound, .badge, .alert])
        }
    }
}
