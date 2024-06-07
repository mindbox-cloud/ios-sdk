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
    private var persistenceStorage: PersistenceStorage!
    private var isVisitSaved: Bool = false
    
    init(container: ModuleInjector = container) {
        container.injectAsync(PersistenceStorage.self) { [weak self] persistenceStorage in
            self?.persistenceStorage = persistenceStorage
        }
    }
}

// MARK: - UserVisitManagerProtocol

extension UserVisitManager: UserVisitManagerProtocol {
    func saveUserVisit() {
        guard !isVisitSaved else {
            Logger.common(message: "Skip changing userVisit because it is already saved", level: .info, category: .visit)
            return
        }
        
        isVisitSaved = true
        
        var previousUserVisitCount = persistenceStorage.userVisitCount ?? UVMConstants.noAppVisits
        
        // Handling the first launch when SDK version has been updated to 2.9.0 or higher from versions below 2.9.0
        let isInstalled = SessionTemporaryStorage.shared.isInstalledFromPersistenceStorageBeforeInitSDK
        if (isInstalled && previousUserVisitCount == UVMConstants.noAppVisits) {
            previousUserVisitCount = UVMConstants.appVisitsWhenSDKHasBeenUpdated
        }
        
        let userVisitCount = previousUserVisitCount + 1
      
        persistenceStorage.userVisitCount = userVisitCount
        
        let message = "UserVisit has been changed from \(previousUserVisitCount) to \(userVisitCount)"
        Logger.common(message: message, level: .info, category: .visit)
    }
}

fileprivate enum UVMConstants {
    static let noAppVisits = 0
    static let appVisitsWhenSDKHasBeenUpdated = 1
}
