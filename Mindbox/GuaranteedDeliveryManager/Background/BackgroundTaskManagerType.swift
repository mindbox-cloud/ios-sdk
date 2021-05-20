//
//  BackgroundTaskManagerType.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 15.02.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
import UIKit

protocol BackgroundTaskManagerType: AnyObject {
    var gdManager: GuaranteedDeliveryManager? { get set }

    func applicationDidEnterBackground()

    func applicationDidBecomeActive()

    func endBackgroundTask(success: Bool)

    func registerBGTasks(
        appGDRefreshIdentifier: String,
        appGDProcessingIdentifier: String,
        appDBCleanProcessingIdentifire: String
    )

    func application(
        _ application: UIApplication,
        performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    )
}

extension BackgroundTaskManagerType {
    func application(
        _ application: UIApplication,
        performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {}

    func registerBGTasks(
        appGDRefreshIdentifier: String,
        appGDProcessingIdentifier: String,
        appDBCleanProcessingIdentifire: String
    ) {}
}
