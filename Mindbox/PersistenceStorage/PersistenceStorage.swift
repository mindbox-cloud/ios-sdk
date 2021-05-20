//
//  PersistenceStorage.swift
//  Mindbox
//
//  Created by Mikhail Barilov on 13.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

protocol PersistenceStorage: AnyObject {
    var installationDate: Date? { get set }

    var deviceUUID: String? { get set }

    var installationId: String? { get set }

    var isInstalled: Bool { get }

    var apnsToken: String? { get set }

    var apnsTokenSaveDate: Date? { get set }

    var deprecatedEventsRemoveDate: Date? { get set }

    var configuration: MBConfiguration? { get set }

    var backgroundExecutions: [BackgroudExecution] { get }

    var isNotificationsEnabled: Bool? { get set }

    func setBackgroundExecution(_ value: BackgroudExecution)

    func reset()

    func resetBackgroundExecutions()

    func storeToFileBackgroundExecution()

    var onDidChange: (() -> Void)? { get set }
}
