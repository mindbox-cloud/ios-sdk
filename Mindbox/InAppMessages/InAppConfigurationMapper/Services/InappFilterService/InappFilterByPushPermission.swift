//
//  InappFilterByPushPermission.swift
//  Mindbox
//
//  Created by vailence on 14.03.2024.
//  Copyright © 2024 Mindbox. All rights reserved.
//

import Foundation
import UserNotifications

protocol InappFilterByPushPermissionProtocol {
    func checkPushPermissionConditionPassed(from variant: MindboxFormVariant) -> Bool
}

class InappFilterByPushPermission: InappFilterByPushPermissionProtocol {
    
    func checkPushPermissionConditionPassed(from variant: MindboxFormVariant) -> Bool {
        switch variant {
            case .modal(let modalFormVariant):
                return checkLayer(modalFormVariant.content.background.layers.first)
            case .snackbar(let snackbarFormVariant):
                return checkLayer(snackbarFormVariant.content.background.layers.first)
            default:
                return true
        }
    }
    
    func checkLayer(_ layer: ContentBackgroundLayer?) -> Bool {
        guard let layer = layer else {
            return false
        }
        
        switch layer {
            case .image(let imageModel):
                switch imageModel.action {
                    case .pushPermission:
                        return checkPushPermission()
                    default:
                        return true
                }
            case .unknown:
                return true
        }
    }
    
    func checkPushPermission() -> Bool {
        switch SessionTemporaryStorage.shared.pushPermissionStatus {
            case .notDetermined, .denied:
                return true
            case .authorized, .provisional, .ephemeral:
                return false
            @unknown default:
                return false
        }
    }
}
