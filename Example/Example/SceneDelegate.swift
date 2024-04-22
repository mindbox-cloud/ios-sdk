//
//  SceneDelegate.swift
//  Example
//
//  Created by Дмитрий Ерофеев on 29.03.2024.
//

import UIKit
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        let window = UIWindow(windowScene: windowScene)
        let viewModel = MainViewModel()
        window.rootViewController = UIHostingController(rootView: MainView(viewModel: viewModel))
        self.window = window
        window.makeKeyAndVisible()
    }
}

