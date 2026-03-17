//
//  PermissionHandler.swift
//  Mindbox
//
//  Created by Akylbek Utekeshev on 13.03.2026.
//  Copyright © 2026 Mindbox. All rights reserved.
//

import Foundation

enum PermissionType: String {
    case pushNotifications
    case location
    case camera
    case microphone
    case photoLibrary
}

enum PermissionRequestResult: Equatable {
    case granted
    case denied
    case error(String)
}

protocol PermissionHandler {
    var permissionType: PermissionType { get }
    var requiredInfoPlistKeys: [String] { get }
    func request(completion: @escaping (PermissionRequestResult) -> Void)
}

protocol PermissionHandlerRegistryProtocol {
    func handler(for type: PermissionType) -> PermissionHandler?
}

final class PermissionHandlerRegistry: PermissionHandlerRegistryProtocol {

    private var handlers: [PermissionType: PermissionHandler] = [:]

    func register(_ handler: PermissionHandler) {
        handlers[handler.permissionType] = handler
    }

    func handler(for type: PermissionType) -> PermissionHandler? {
        handlers[type]
    }
}
