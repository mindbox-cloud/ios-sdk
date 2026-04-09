//
//  SceneDelegate.swift
//  Example
//
//  Created by Дмитрий Ерофеев on 29.03.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import UIKit
import SwiftUI
import Mindbox

final class SceneDelegate: MindboxSceneDelegate {

    var window: UIWindow?

    override func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        super.scene(scene, willConnectTo: session, options: connectionOptions)
        
        guard let windowScene = (scene as? UIWindowScene) else { return }
        let window = UIWindow(windowScene: windowScene)
        let viewModel = MainViewModel()
        window.rootViewController = UIHostingController(rootView: MainView(viewModel: viewModel))
        self.window = window
        window.makeKeyAndVisible()
        
        // Handle Universal Link on a cold start:
        // The app was launched from a URL (not already running).
        // Read the link from `connectionOptions.userActivities` and route to the right screen.
    }
    
    // https://developers.mindbox.ru/docs/universal-links#ios
    override func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        super.scene(scene, continue: userActivity)
        
        // Handle Universal Link on a warm start:
        // The app is already running (foreground or background) and receives a new URL.
        // Use `scene(_:continue:)` to parse and route the link.
    }
}
