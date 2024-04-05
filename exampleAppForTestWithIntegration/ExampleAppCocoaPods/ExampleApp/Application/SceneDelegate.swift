//
//  SceneDelegate.swift
//  ExampleApp
//
//  Created by Sergei Semko on 3/11/24.
//

import UIKit
import FirebaseCrashlytics

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
        Crashlytics.crashlytics().log("Finished \(#function),: isProtectedDataAvailable: \(UIApplication.shared.isProtectedDataAvailable)")
    }
    
    func sceneWillEnterForeground(_ scene: UIScene) {
        EALogManager.shared.log(#function)
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        EALogManager.shared.log(#function)
    }
    
    func sceneWillResignActive(_ scene: UIScene) {
        EALogManager.shared.log(#function)
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        EALogManager.shared.log(#function)
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
        EALogManager.shared.log(#function)
    }
}

