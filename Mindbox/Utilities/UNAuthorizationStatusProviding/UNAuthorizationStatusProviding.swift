//
//  UNAuthorizationStatusProviding.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 09.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

protocol UNAuthorizationStatusProviding {
    
    func getStatus(result: @escaping (Bool) -> Void)
}
