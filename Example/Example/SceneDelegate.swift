//
//  SceneDelegate.swift
//  Example
//
//  Created by Дмитрий Ерофеев on 29.03.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import UIKit
import SwiftUI

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        print(#function)
        guard let windowScene = (scene as? UIWindowScene) else { return }
        let window = UIWindow(windowScene: windowScene)
        let viewModel = ViewModel()
        window.rootViewController = UIHostingController(rootView: ContentView(webViewModel: viewModel))
        self.window = window
        window.makeKeyAndVisible()
    }
}
