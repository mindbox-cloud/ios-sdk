//
//  PushPermissionActionUseCase.swift
//  Mindbox
//
//  Created by vailence on 14.03.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation
import UIKit
import MindboxLogger

extension ContentBackgroundLayerAction {
    /// Delegates to `ActionUseCaseFactory` to extract URL/payload and handle side effects.
    /// Returns `nil` for `.unknown` or empty redirect actions (no callback should be invoked).
    func handleTap() -> (url: URL?, payload: String)? {
        guard let useCase = ActionUseCaseFactory.createUseCase(action: self) else {
            return nil
        }
        return useCase.execute()
    }
}

final class PushPermissionActionUseCase: PresentationActionUseCaseProtocol {

    private let model: PushPermissionLayerAction

    init(model: PushPermissionLayerAction) {
        self.model = model
    }

    func execute() -> (url: URL?, payload: String)? {
        PushPermissionHelper.requestPermission { result in
            if case .denied(dialogShown: false) = result {
                PushPermissionHelper.openPushNotificationSettings()
            }
        }
        return (nil, model.intentPayload)
    }
}

enum PushPermissionHelper {

    static func requestPermission(completion: ((PermissionRequestResult) -> Void)? = nil) {
        let registry = DI.injectOrFail(PermissionHandlerRegistryProtocol.self)
        registry.handler(for: .pushNotifications)?.request { result in
            completion?(result)
        }
    }

    static func openPushNotificationSettings() {
        DispatchQueue.main.async {
            let settingsUrl: URL?
            if #available(iOS 16.0, *) {
                settingsUrl = URL(string: UIApplication.openNotificationSettingsURLString)
            } else {
                settingsUrl = URL(string: UIApplication.openSettingsURLString)
            }
            guard let settingsUrl = settingsUrl, UIApplication.shared.canOpenURL(settingsUrl) else {
                Logger.common(message: "Failed to parse the settings URL or encountered an issue opening it.", level: .debug, category: .inAppMessages)
                return
            }
            UIApplication.shared.open(settingsUrl)
            Logger.common(message: "Navigated to app settings for notification permission.", level: .debug, category: .inAppMessages)
        }
    }
}
