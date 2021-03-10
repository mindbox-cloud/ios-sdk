//
//  UNAuthorizationStatusProvider.swift
//  MindBox
//
//  Created by Maksim Kazachkov on 09.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
import UIKit

class UNAuthorizationStatusProvider: UNAuthorizationStatusProviding {
    
    private var authorizationStatus: UNAuthorizationStatus?
    
    private var isAuthorized: Bool {
        authorizationStatus?.rawValue == UNAuthorizationStatus.authorized.rawValue
    }
    
    init() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: nil) { [weak self] (_) in
            self?.authorizationStatus = nil
        }
    }

    func isAuthorized(completion: @escaping (Bool) -> Void) {
        if authorizationStatus != nil {
            completion(isAuthorized)
        } else {
            UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
                guard let self = self else {
                    return
                }
                self.authorizationStatus = settings.authorizationStatus
                completion(self.isAuthorized)
            }
        }
    }
    
}
