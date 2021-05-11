//
//  MindboxSceneDelegate.swift
//  Mindbox
//
//  Created by Ihor Kandaurov on 07.05.2021.
//

import UIKit

@available(iOS 13.0, *)
open class MindboxSceneDelegate: UIResponder, UIWindowSceneDelegate {
    open var window: UIWindow?

    open func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        Mindbox.shared.track(.launchScene(connectionOptions))
        guard let _ = (scene as? UIWindowScene) else { return }
    }

    open func scene(
        _ scene: UIScene,
        continue userActivity: NSUserActivity
    ) {
        Mindbox.shared.track(.universalLink(userActivity))
    }
}
