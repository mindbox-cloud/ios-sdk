//
//  SceneDelegate.swift
//  ExampleApp
//
//  Created by Sergei Semko on 3/11/24.
//

import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        window = UIWindow(windowScene: windowScene)
        
        let viewController = ViewController()
        
        window?.rootViewController = viewController
        window?.makeKeyAndVisible()
        
        EALogManager.shared.log(#function)
    }
}

