//
//  Utilities.swift
//  Mindbox
//
//  Created by Mikhail Barilov on 20.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
import UIKit.UIApplication

protocol UtilitiesFetcher {

    var appVerson: String? { get }
    var sdkVersion: String? { get }
    var hostApplicationName: String? { get }
    
    var applicationGroupIdentifier: String { get }
    
    func getDeviceUUID(completion: @escaping (String) -> Void)
    
}
