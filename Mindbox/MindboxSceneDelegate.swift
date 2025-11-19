//
//  MindboxSceneDelegate.swift
//  Mindbox
//
//  Created by Ihor Kandaurov on 07.05.2021.
//

import UIKit

@available(iOS 13.0, *)
open class MindboxSceneDelegate: UIResponder, UIWindowSceneDelegate {

    open func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        Mindbox.shared.track(.launchScene(connectionOptions))
    }

    open func scene(
        _ scene: UIScene,
        continue userActivity: NSUserActivity
    ) {
        Mindbox.shared.track(.universalLink(userActivity))
    }
}
