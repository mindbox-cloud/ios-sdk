//
//  InappPresentationValidator.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 26.05.2025.
//  Copyright © 2025 Mindbox. All rights reserved.
//

import Foundation
import MindboxLogger

protocol InAppPresentationValidatorProtocol {
    func canPresentInApp() -> Bool
}

final class InAppPresentationValidator: InAppPresentationValidatorProtocol {
    private let persistenceStorage: PersistenceStorage
    
    init(persistenceStorage: PersistenceStorage) {
        self.persistenceStorage = persistenceStorage
    }
    
    func canPresentInApp() -> Bool {
        // Проверяем что инапп не показывается в данный момент
        guard !SessionTemporaryStorage.shared.isPresentingInAppMessage else {
            Logger.common(message: "[PresentationValidator] Another in-app is already being shown. Skip in-app", level: .debug, category: .inAppMessages)
            return false
        }

        return true
    }
}
