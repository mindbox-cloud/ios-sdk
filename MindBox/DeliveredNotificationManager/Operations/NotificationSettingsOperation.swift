//
//  NotificationSettingsOperation.swift
//  MindBox
//
//  Created by Maksim Kazachkov on 10.03.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation

final class NotificationSettingsOperation: Operation {
    
    @Injected private var notificationStatusProvider: UNAuthorizationStatusProviding
    @Injected private var databaseRepository: MBDatabaseRepository
    @Injected private var persistenceStorage: PersistenceStorage
    
    private var _isFinished: Bool = false
    override var isFinished: Bool {
        get {
            return _isFinished
        }
        set {
            willChangeValue(for: \.isFinished)
            _isFinished = newValue
            didChangeValue(for: \.isFinished)
        }
    }
        
    override func main() {
        guard !isCancelled else {
            return
        }
        notificationStatusProvider.isAuthorized { [weak self] isNotificationsEnabled in
            guard let self = self else {
                return
            }
            guard let isPersistentNotificationsEnabled = self.persistenceStorage.isNotificationsEnabled else  {
                self.isFinished = true
                return
            }
            guard isPersistentNotificationsEnabled != isNotificationsEnabled else {
                self.isFinished = true
                return
            }
            self.persistenceStorage.isNotificationsEnabled = isNotificationsEnabled
            let apnsToken = self.persistenceStorage.apnsToken
            let infoUpdated = MobileApplicationInfoUpdated(
                token: apnsToken ?? "",
                isNotificationsEnabled: isNotificationsEnabled
            )
            let event = Event(
                type: .infoUpdated,
                body: BodyEncoder(encodable: infoUpdated).body
            )
            try? self.databaseRepository.create(event: event)
            self.isFinished = true
        }
    }
    
}
