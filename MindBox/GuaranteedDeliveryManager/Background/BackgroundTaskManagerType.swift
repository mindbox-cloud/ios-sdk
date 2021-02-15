//
//  BackgroundTaskManagerType.swift
//  MindBox
//
//  Created by Maksim Kazachkov on 15.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

protocol BackgroundTaskManagerType: class {

    func applicationDidEnterBackground()
    func applicationDidBecomeActive()
    func endBackgroundTask(success: Bool)
    func registerTask(with identifier: String)
    
}
