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
import AppTrackingTransparency

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        let window = UIWindow(windowScene: windowScene)
        let viewModel = MainViewModel()
        window.rootViewController = UIHostingController(rootView: MainView(viewModel: viewModel))
        self.window = window
        window.makeKeyAndVisible()
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        print(#function)
        if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            print("ATTrackingManager.trackingAuthorizationStatus == .notDetermined")
            DispatchQueue.main.async {
                ATTrackingManager.requestTrackingAuthorization { status in
                    print("Inside ATTrackingManager.requestTrackingAuthorization")
                    DispatchQueue.main.async {
                        (UIApplication.shared.delegate as? AppDelegate)?.initializeMindbox()
                    }
                }
            }
        }

    }
}

