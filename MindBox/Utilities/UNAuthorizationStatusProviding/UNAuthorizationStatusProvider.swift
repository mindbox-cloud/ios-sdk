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
    
    private let semathore = DispatchSemaphore(value: 0)
    
    func isNotificationsEnabled() -> Bool {
        var isAuthorized: Bool = false
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            isAuthorized = settings.authorizationStatus.rawValue == UNAuthorizationStatus.authorized.rawValue
            self?.semathore.signal()
        }
        semathore.wait()
        return isAuthorized
    }
    
}
