//
//  InappActionHandler.swift
//  FirebaseCore
//
//  Created by vailence on 10.08.2023.
//

import Foundation
import MindboxLogger

protocol InAppActionHandlerProtocol {
    func handleAction(
        _ action: ContentBackgroundLayerAction,
        for id: String,
        onTap: @escaping InAppMessageTapAction,
        close: @escaping () -> Void
    )
}

final class InAppActionHandler: InAppActionHandlerProtocol {
    
    private let actionUseCaseFactory: UseCaseFactoryProtocol
    
    init(actionUseCaseFactory: UseCaseFactoryProtocol) {
        self.actionUseCaseFactory = actionUseCaseFactory
    }

    func handleAction(_ action: ContentBackgroundLayerAction,
                      for id: String,
                      onTap: @escaping InAppMessageTapAction,
                      close: @escaping () -> Void) {
        
        guard let action = actionUseCaseFactory.createUseCase(action: action) else {
            return 
        }
        
        action.onTapAction(id: id, onTap: onTap, close: close)
    }
}
