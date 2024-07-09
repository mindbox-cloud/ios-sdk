//
//  DependencyContainer.swift
//  Mindbox
//
//  Created by Maksim Kazachkov on 22.03.2021.
//  Copyright © 2021 Mindbox. All rights reserved.
//

import Foundation

protocol DependencyContainer {
    var utilitiesFetcher: UtilitiesFetcher { get }
    var databaseRepository: MBDatabaseRepository { get }
    var inAppMessagesManager: InAppCoreManagerProtocol { get }
    var inappMessageEventSender: InappMessageEventSender { get }
    var inappFilterService: InappFilterProtocol { get }
}
