//
//  PresentationStrategyProtocol.swift
//  Mindbox
//
//  Created by vailence on 18.07.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import UIKit
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
/// The exception is a page listening for a shake: the system delivers a shake to the key window alone.
final class MindboxInAppWindow: UIWindow {

    /// Whether the window may become key. Off unless the page asked for a shake.
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
