//
//  PresentationStrategyProtocol.swift
//  Mindbox
//
//  Created by vailence on 18.07.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import UIKit
import UserNotifications
import MindboxLogger

protocol PresentationStrategyProtocol {
    var window: UIWindow? { get set }

    func getWindow() -> UIWindow?
    func present(id: String, in window: UIWindow, using viewController: UIViewController) -> Bool
    func dismiss(viewController: UIViewController)
    func setupWindowFrame(model: MindboxFormVariant, imageSize: CGSize)
}

/// The window an in-app is shown in. Its own class, so the host's windows can be told apart from ours.
///
/// It does not take key from the host: on a deeplink a host often routes from the key window,
/// and finding our controller there instead of its own crashes it or loses the screen it opens.
/// A touch makes a window key by itself, so refusing key is the only way to stay out of the way.
/// The exception is a page editing text: the keyboard types into the key window alone.
final class MindboxInAppWindow: UIWindow {

    /// Whether the window may become key. Off unless the page edits text.
    var allowsKey = false

    @available(iOS 15.0, *)
    override var canBecomeKey: Bool {
        allowsKey && super.canBecomeKey
    }
}

/// Keeps key on the host's window while an in-app is up.
protocol InAppKeyWindowReturning: AnyObject {

    /// The host's key window right now — ours never count. Main thread only.
    func hostKeyWindow() -> UIWindow?

    /// If one of our windows holds key, gives it back: to `preferred` while that window is still up,
    /// otherwise to the host's frontmost window of the same scene. Main thread only.
    func returnKeyToHost(preferring preferred: UIWindow?)
}

final class InAppKeyWindowReturner: InAppKeyWindowReturning {

    /// Every scene's windows. Injectable for a test host whose windows belong to no scene.
    private let windows: () -> [UIWindow]

    init(windows: @escaping () -> [UIWindow] = { UIApplication.shared.windows }) {
        self.windows = windows
    }

    func hostKeyWindow() -> UIWindow? {
        guard Thread.isMainThread else { return nil }

        return windows().first { $0.isKeyWindow && !($0 is MindboxInAppWindow) }
    }

    func returnKeyToHost(preferring preferred: UIWindow?) {
        guard Thread.isMainThread else { return }

        let windows = windows()
        guard let ourKeyWindow = windows.first(where: { $0.isKeyWindow }) as? MindboxInAppWindow else { return }

        let target: UIWindow?
        if let preferred, Self.canTakeKeyBack(preferred) {
            target = preferred
        } else {
            target = windows.last { window in
                Self.canTakeKeyBack(window)
                    && window.windowLevel == .normal
                    && Self.isInSameScene(window, as: ourKeyWindow)
            }
        }

        guard let target else {
            Logger.common(message: "[InAppKeyWindow] No host window to give key back to, the in-app window keeps it",
                          level: .error, category: .inAppMessages)
            return
        }

        target.makeKey()
        Logger.common(message: "[InAppKeyWindow] Key given back to the host window", category: .inAppMessages)
    }

    private static func canTakeKeyBack(_ window: UIWindow) -> Bool {
        !(window is MindboxInAppWindow) && !window.isHidden && window.alpha > 0
    }

    private static func isInSameScene(_ window: UIWindow, as other: UIWindow) -> Bool {
        if #available(iOS 13.0, *) {
            return window.windowScene === other.windowScene
        }
        return true
    }
}

/// Gives key back to the host before the host handles a link or a tap on a push.
///
/// While a page edits text, the in-app window must be key, and a link or a push tap delivered to the
/// active app does not make it inactive: the host's handler would find our controller in the key window.
/// So on the first text editing the host's entry points are wrapped, once per class and selector:
/// key goes back to the host, then the host's code runs exactly as before.
enum HostEntryKeyGuard {

    private static var guardedMethods = Set<String>()

    /// Main thread only. Leaves an extension, or a process with no application, alone.
    static func installIfNeeded(returner: InAppKeyWindowReturning = InAppKeyWindowReturner()) {
        guard !Bundle.main.bundlePath.hasSuffix(".appex"),
              object_getClass(UIApplication.shared) != nil else { return }

        if let delegate = UNUserNotificationCenter.current().delegate, let delegateClass = object_getClass(delegate) {
            guardPushTaps(of: delegateClass, returner: returner)
        }
        if let delegate = UIApplication.shared.delegate, let delegateClass = object_getClass(delegate) {
            guardApplicationLinks(of: delegateClass, returner: returner)
        }
        if #available(iOS 13.0, *) {
            for scene in UIApplication.shared.connectedScenes {
                if let delegate = scene.delegate, let delegateClass = object_getClass(delegate) {
                    guardSceneLinks(of: delegateClass, returner: returner)
                }
            }
        }
    }

    /// `userNotificationCenter(_:didReceive:withCompletionHandler:)`.
    static func guardPushTaps(of delegateClass: AnyClass, returner: InAppKeyWindowReturning) {
        let selector = #selector(UNUserNotificationCenterDelegate.userNotificationCenter(_:didReceive:withCompletionHandler:))
        typealias Original = @convention(c) (AnyObject, Selector, UNUserNotificationCenter, UNNotificationResponse, @escaping () -> Void) -> Void
        typealias Guarded = @convention(block) (AnyObject, UNUserNotificationCenter, UNNotificationResponse, @escaping () -> Void) -> Void
        wrap(delegateClass, selector) { implementation in
            let original = unsafeBitCast(implementation, to: Original.self)
            let guarded: Guarded = { delegate, center, response, completion in
                returner.returnKeyToHost(preferring: nil)
                original(delegate, selector, center, response, completion)
            }
            return guarded
        }
    }

    /// `application(_:open:options:)` and `application(_:continue:restorationHandler:)`.
    static func guardApplicationLinks(of delegateClass: AnyClass, returner: InAppKeyWindowReturning) {
        let openURL = #selector(UIApplicationDelegate.application(_:open:options:))
        typealias OpenOriginal = @convention(c) (AnyObject, Selector, UIApplication, NSURL, NSDictionary) -> Bool
        typealias OpenGuarded = @convention(block) (AnyObject, UIApplication, NSURL, NSDictionary) -> Bool
        wrap(delegateClass, openURL) { implementation in
            let original = unsafeBitCast(implementation, to: OpenOriginal.self)
            let guarded: OpenGuarded = { delegate, application, url, options in
                returner.returnKeyToHost(preferring: nil)
                return original(delegate, openURL, application, url, options)
            }
            return guarded
        }

        let continueActivity = #selector(UIApplicationDelegate.application(_:continue:restorationHandler:))
        typealias ContinueOriginal = @convention(c) (AnyObject, Selector, UIApplication, NSUserActivity, AnyObject?) -> Bool
        typealias ContinueGuarded = @convention(block) (AnyObject, UIApplication, NSUserActivity, AnyObject?) -> Bool
        wrap(delegateClass, continueActivity) { implementation in
            let original = unsafeBitCast(implementation, to: ContinueOriginal.self)
            let guarded: ContinueGuarded = { delegate, application, activity, restorationHandler in
                returner.returnKeyToHost(preferring: nil)
                return original(delegate, continueActivity, application, activity, restorationHandler)
            }
            return guarded
        }
    }

    /// `scene(_:openURLContexts:)` and `scene(_:continue:)`.
    @available(iOS 13.0, *)
    static func guardSceneLinks(of delegateClass: AnyClass, returner: InAppKeyWindowReturning) {
        let openURLContexts = #selector(UISceneDelegate.scene(_:openURLContexts:))
        typealias OpenOriginal = @convention(c) (AnyObject, Selector, UIScene, NSSet) -> Void
        typealias OpenGuarded = @convention(block) (AnyObject, UIScene, NSSet) -> Void
        wrap(delegateClass, openURLContexts) { implementation in
            let original = unsafeBitCast(implementation, to: OpenOriginal.self)
            let guarded: OpenGuarded = { delegate, scene, contexts in
                returner.returnKeyToHost(preferring: nil)
                original(delegate, openURLContexts, scene, contexts)
            }
            return guarded
        }

        let continueActivity = #selector(UISceneDelegate.scene(_:continue:))
        typealias ContinueOriginal = @convention(c) (AnyObject, Selector, UIScene, NSUserActivity) -> Void
        typealias ContinueGuarded = @convention(block) (AnyObject, UIScene, NSUserActivity) -> Void
        wrap(delegateClass, continueActivity) { implementation in
            let original = unsafeBitCast(implementation, to: ContinueOriginal.self)
            let guarded: ContinueGuarded = { delegate, scene, activity in
                returner.returnKeyToHost(preferring: nil)
                original(delegate, continueActivity, scene, activity)
            }
            return guarded
        }
    }

    /// Wraps `selector` of `targetClass` once, if the class has it: a host without the handler routes nothing.
    private static func wrap(_ targetClass: AnyClass, _ selector: Selector, guarding makeBlock: (IMP) -> Any) {
        let key = NSStringFromClass(targetClass) + "|" + NSStringFromSelector(selector)
        guard guardedMethods.insert(key).inserted,
              let method = class_getInstanceMethod(targetClass, selector) else { return }

        let implementation = imp_implementationWithBlock(makeBlock(method_getImplementation(method)))
        // Added on the class itself when it inherits the method, so no other class changes.
        if !class_addMethod(targetClass, selector, implementation, method_getTypeEncoding(method)) {
            method_setImplementation(method, implementation)
        }
        Logger.common(message: "[InAppKeyWindow] \(NSStringFromSelector(selector)) gives key back to the host first",
                      category: .inAppMessages)
    }
}
