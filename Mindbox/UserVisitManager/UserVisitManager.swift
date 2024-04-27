//
//  UserVisitManager.swift
//  Mindbox
//
//  Created by Egor Kitseliuk on 22.03.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

protocol UserVisitManagerProtocol {
    func saveUserVisit()
}

final class UserVisitManager {
    private let persistenceStorage: PersistenceStorage
    private let sessionManager: SessionManager
    private var isVisitSaved: Bool = false
    
    init(persistenceStorage: PersistenceStorage, sessionManager: SessionManager) {
        self.persistenceStorage = persistenceStorage
        self.sessionManager = sessionManager
    }
}

// MARK: - UserVisitManagerProtocol

extension UserVisitManager: UserVisitManagerProtocol {
    func saveUserVisit() {
        guard !isVisitSaved else {
            Logger.common(message: "Skip changing userVisit because it is already saved", level: .info, category: .visit)
            return
        }
        
        let isActive = sessionManager.isActiveNow
        let isInit = SessionTemporaryStorage.shared.isInitializationCalled
        guard isActive && isInit else {
            if (!isActive) {
                Logger.common(message: "Skip changing userVisit because it is initialized in an not active state.", level: .info, category: .visit)
            } else {
                Logger.common(message: "Skip changing userVisit because it is not initialized.", level: .info, category: .visit)
            }
            return
        }
        
        isVisitSaved = true
        let deviceUUID = persistenceStorage.deviceUUID
        var previosUserVisitCount = persistenceStorage.userVisitCount ?? 0
        if (deviceUUID != nil && previosUserVisitCount == 0) {
            previosUserVisitCount = 1
        }
        
        let userVisitCount = previosUserVisitCount + 1
      
        persistenceStorage.userVisitCount = userVisitCount
        Logger.common(message: "UserVisit has been changed from \(previosUserVisitCount) to \(userVisitCount)", level: .info, category: .visit)
    }
}
