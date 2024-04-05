//
//  UNAuthorizationStatusProvider.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 09.02.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation
import UIKit

class UNAuthorizationStatusProvider: UNAuthorizationStatusProviding {
    
    func getStatus(result: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            SessionTemporaryStorage.shared.pushPermissionStatus = settings.authorizationStatus
            var grantedStatused = [UNAuthorizationStatus.authorized]
            if #available(iOS 12.0, *) {
                grantedStatused.append(UNAuthorizationStatus.provisional)
            }
            let isAuthorized = grantedStatused.contains(settings.authorizationStatus)
            result(isAuthorized)
        }
    }
}
