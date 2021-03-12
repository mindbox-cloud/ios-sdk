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

    func isAuthorized(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let isAuthorized = settings.authorizationStatus.rawValue == UNAuthorizationStatus.authorized.rawValue
            completion(isAuthorized)
        }
    }
    
}
